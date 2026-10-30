import Testing
import Foundation

@testable import scheman

@Suite struct TargetTests {
    @Test(arguments: [
        ("mailto", "mailto://"), ("mailto:", "mailto://"), ("HTTPS://", "https://"), ("x-callback-url", "x-callback-url://"),
        (".md", "net.daringfireball.markdown"), (".json", "public.json"),
        ("text/plain", "public.plain-text"), ("public.json", "public.json"),
    ])
    func parses(raw: String, label: String) throws {
        #expect(try parseTarget(raw).label == label)
    }

    @Test(arguments: ["", ".", "not.a.known.uti.zzz", "bad scheme", "a/b:c"])
    func rejects(raw: String) {
        #expect(throws: TargetError.self) { try parseTarget(raw) }
    }
}

@Suite struct CLITests {
    @Test func noArgumentsShowsHelp() throws {
        #expect(try parseInvocation([]) == .help(nil))
    }

    @Test func parsesFlagsAndArguments() throws {
        #expect(try parseInvocation(["get", "--json", "mailto", ".md"]) == .run("get", Parsed(flags: ["--json"], arguments: ["mailto", ".md"])))
    }

    @Test func dashDashEndsOptions() throws {
        #expect(try parseInvocation(["get", "--", "-x"]) == .run("get", Parsed(flags: [], arguments: ["-x"])))
    }

    @Test func commandHelp() throws {
        #expect(try parseInvocation(["set", "-h"]) == .help("set"))
        #expect(try parseInvocation(["help", "set"]) == .help("set"))
    }

    @Test func version() throws {
        #expect(try parseInvocation(["--version"]) == .version)
    }

    @Test(arguments: [["nope"], ["help", "nope"], ["get"], ["set", "Safari"], ["schemes", "extra"], ["get", "--bad", "x"]])
    func usageErrors(args: [String]) {
        #expect(throws: UsageError.self) { try parseInvocation(args) }
    }

    @Test func setHelpShowsUsage() {
        #expect(helpText(for: "set").hasPrefix("Usage: scheman set <app> <target>..."))
    }

    @Test func completionsKnownShells() {
        #expect(completionScript(for: "zsh")?.hasPrefix("#compdef scheman") == true)
        #expect(completionScript(for: "tcsh") == nil)
    }
}

@Suite struct OutputTests {
    @Test func tablePadsAllButLastColumn() {
        let text = table(["A", "BB"], [["xxx", "1"], ["y", "22"]])
        #expect(text == "A    BB\nxxx  1\ny    22")
    }

    @Test func jsonSortsKeysAndKeepsSlashes() throws {
        struct Item: Encodable {
            let path: String
            let name: String
        }
        #expect(try json(Item(path: "/a/b", name: "x")) == "{\n  \"name\" : \"x\",\n  \"path\" : \"/a/b\"\n}")
    }
}

@Suite struct HelpTests {
    @Test func topLevelHelpListsEveryCommand() {
        let text = helpText(for: nil)
        for name in ["schemes", "apps", "get", "set", "completion"] {
            #expect(text.contains("  \(name) "))
        }
    }

    @Test func unknownCommandFallsBackToTopLevelHelp() {
        #expect(helpText(for: "nope").hasPrefix("Usage: scheman <command> [options]"))
    }

    @Test func commandHelpListsFlags() {
        let text = helpText(for: "schemes")
        #expect(text.hasPrefix("Usage: scheman schemes [options]"))
        #expect(text.contains("--all"))
        #expect(text.contains("--json"))
    }

    @Test func completionHelpShowsInstallSteps() {
        #expect(helpText(for: "completion").contains("Install:"))
    }
}

@Suite struct CompletionTests {
    @Test(arguments: [
        ("zsh", "#compdef scheman"), ("bash", "_scheman() {"), ("fish", "complete -c scheman -f"),
    ])
    func scriptStartsWithShellHeader(shell: String, prefix: String) {
        #expect(completionScript(for: shell)?.hasPrefix(prefix) == true)
    }

    @Test(arguments: ["zsh", "bash", "fish"])
    func scriptMentionsEveryCommand(shell: String) throws {
        let script = try #require(completionScript(for: shell))
        for name in ["schemes", "apps", "get", "set", "completion"] {
            #expect(script.contains(name))
        }
    }
}

@Suite struct ParseInvocationEdgeTests {
    @Test func shortVersionFlag() throws {
        #expect(try parseInvocation(["-V"]) == .version)
    }

    @Test func singleDashIsAnArgument() throws {
        #expect(try parseInvocation(["get", "-"]) == .run("get", Parsed(flags: [], arguments: ["-"])))
    }

    @Test func helpWithoutNameShowsTopLevelHelp() throws {
        #expect(try parseInvocation(["help"]) == .help(nil))
    }

    @Test func usageErrorNamesTheCommand() {
        #expect(throws: UsageError.self) { try parseInvocation(["schemes", "--bad"]) }
        do {
            _ = try parseInvocation(["schemes", "--bad"])
        } catch let error as UsageError {
            #expect(error.command == "schemes")
            #expect(error.message == "unknown option '--bad'")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func completionNeedsExactlyOneShell() {
        #expect(throws: UsageError.self) { try parseInvocation(["completion"]) }
        #expect(throws: UsageError.self) { try parseInvocation(["completion", "zsh", "bash"]) }
    }
}

@Suite struct TargetEdgeTests {
    @Test func trimsWhitespaceAndLowercasesScheme() throws {
        #expect(try parseTarget("  MAILTO:  ").label == "mailto://")
    }

    @Test func extensionAndMimeAgree() throws {
        #expect(try parseTarget(".txt").label == parseTarget("text/plain").label)
    }
}

@Suite struct AppTests {
    /// Builds a minimal `.app` bundle in a fresh temporary directory.
    static func makeApp(named name: String, bundleID: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contents = root.appendingPathComponent("\(name).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundleName": name]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        return root.appendingPathComponent("\(name).app")
    }

    @Test func readsNameAndBundleID() throws {
        let url = try Self.makeApp(named: "Fixture", bundleID: "dev.example.fixture")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let app = App(url: url)
        #expect(app.name == "Fixture")
        #expect(app.bundleID == "dev.example.fixture")
        #expect(app.label == "Fixture (dev.example.fixture)")
    }

    @Test func resolvesAppByPath() throws {
        let url = try Self.makeApp(named: "PathFixture", bundleID: "dev.example.pathfixture")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(try resolveApp(url.path) == url)
    }

    @Test func unknownAppThrowsHelpfulError() {
        #expect(throws: AppResolveError.self) { try resolveApp("No Such App zzz 12345") }
    }

    @Test func matchesNameIgnoringCase() throws {
        let url = try Self.makeApp(named: "Fixture", bundleID: "dev.example.fixture")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let apps = [App(url: url)]
        #expect(matchByName("fIXTURE", in: apps).count == 1)
        #expect(matchByName("other", in: apps).isEmpty)
    }
}
