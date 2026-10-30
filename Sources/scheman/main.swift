import AppKit

struct SchemeRow: Codable {
    let scheme: String
    let defaultApp: App?
    let apps: [App]
}

struct AppRow: Codable {
    let app: App
    let schemes: [String]
}

struct Lookup: Codable {
    let target: String
    let defaultApp: App?
    let apps: [App]
}

func runSchemes(_ parsed: Parsed) throws {
    let all = parsed.flags.contains("--all")
    let names = Set(installedApps().flatMap(\.schemes)).sorted()
    let rows = names.compactMap { name -> SchemeRow? in
        let target = Target.scheme(name)
        let apps = allApps(for: target)
        let def = defaultApp(for: target)
        return def == nil && apps.isEmpty ? nil : SchemeRow(scheme: name, defaultApp: def, apps: apps)
    }
    if parsed.flags.contains("--json") {
        out(try json(rows))
    } else if all {
        out(table(["SCHEME", "DEFAULT", "APPS"], rows.map { [$0.scheme, $0.defaultApp?.name ?? "-", $0.apps.map(\.name).joined(separator: ", ")] }))
    } else {
        out(table(["SCHEME", "DEFAULT"], rows.map { [$0.scheme, $0.defaultApp?.name ?? "-"] }))
    }
}

func runApps(_ parsed: Parsed) throws {
    let includeAll = parsed.flags.contains("--all")
    let rows = installedApps().filter { includeAll || !$0.schemes.isEmpty }
    if parsed.flags.contains("--names") {
        rows.forEach { out($0.app.name) }
    } else if parsed.flags.contains("--json") {
        out(try json(rows.map { AppRow(app: $0.app, schemes: $0.schemes) }))
    } else {
        out(table(["APP", "BUNDLE ID", "SCHEMES"], rows.map { [$0.app.name, $0.app.bundleID ?? "-", $0.schemes.joined(separator: ", ")] }))
    }
}

func runGet(_ parsed: Parsed) throws -> Int32 {
    var status: Int32 = 0
    var lookups: [Lookup] = []
    for raw in parsed.arguments {
        do {
            let target = try parseTarget(raw)
            lookups.append(Lookup(target: target.label, defaultApp: defaultApp(for: target), apps: allApps(for: target)))
        } catch {
            err("Error: \(error)")
            status = 1
        }
    }
    if parsed.flags.contains("--json") {
        out(try json(lookups))
    } else {
        for lookup in lookups {
            out(lookup.target)
            out("  default: \(lookup.defaultApp?.label ?? "none")")
            out("  apps:    \(lookup.apps.isEmpty ? "none" : lookup.apps.map(\.label).joined(separator: "\n           "))")
        }
    }
    return status
}

func runSet(_ parsed: Parsed) async throws -> Int32 {
    let appURL = try resolveApp(parsed.arguments[0])
    let name = App(url: appURL).name
    var status: Int32 = 0
    for raw in parsed.arguments.dropFirst() {
        do {
            let target = try parseTarget(raw)
            if case .scheme(let scheme) = target, scheme == "http" || scheme == "https" {
                err("Note: macOS asks you to confirm the default browser change.")
            }
            try await setDefault(appURL: appURL, for: target)
            out("ok    \(target.label) -> \(name)")
        } catch {
            err("fail  \(raw): \(error.localizedDescription)")
            status = 1
        }
    }
    return status
}

func run(_ invocation: Invocation) async throws -> Int32 {
    switch invocation {
    case .help(let name):
        out(helpText(for: name))
    case .version:
        out("scheman \(version)")
    case .run("schemes", let parsed):
        try runSchemes(parsed)
    case .run("apps", let parsed):
        try runApps(parsed)
    case .run("get", let parsed):
        return try runGet(parsed)
    case .run("set", let parsed):
        return try await runSet(parsed)
    case .run(_, let parsed):  // completions
        guard let script = completionScript(for: parsed.arguments[0]) else {
            throw UsageError(message: "unknown shell '\(parsed.arguments[0])', expected zsh, bash, or fish", command: "completion")
        }
        out(script)
    }
    return 0
}

do {
    exit(try await run(parseInvocation(Array(CommandLine.arguments.dropFirst()))))
} catch let error as UsageError {
    let usage = commands.first { $0.name == error.command }.map(usageLine) ?? helpText(for: nil)
    err("Error: \(error.message)\n\n\(usage)")
    exit(usageExitCode)
} catch {
    err("Error: \(error)")
    exit(1)
}
