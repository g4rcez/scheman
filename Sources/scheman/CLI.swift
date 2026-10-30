import Foundation

let version = "0.1.0"
let usageExitCode: Int32 = 64  // EX_USAGE

struct Flag {
    let name: String
    let help: String
}

struct Command {
    let name: String
    let summary: String
    let arguments: String
    let minArguments: Int
    let maxArguments: Int?
    let flags: [Flag]
}

let jsonFlag = Flag(name: "--json", help: "Print JSON")

let commands: [Command] = [
    Command(
        name: "schemes", summary: "List URL schemes with their default app",
        arguments: "", minArguments: 0, maxArguments: 0,
        flags: [Flag(name: "--all", help: "Also list every app that can handle each scheme"), jsonFlag]),
    Command(
        name: "apps", summary: "List apps that declare URL schemes",
        arguments: "", minArguments: 0, maxArguments: 0,
        flags: [
            Flag(name: "--all", help: "Include apps that declare no URL scheme"),
            Flag(name: "--names", help: "Print only app names, one per line"),
            jsonFlag,
        ]),
    Command(
        name: "get", summary: "Show the default app and all apps for a scheme or file type",
        arguments: "<target>...", minArguments: 1, maxArguments: nil, flags: [jsonFlag]),
    Command(
        name: "set", summary: "Set the default app for schemes and file types",
        arguments: "<app> <target>...", minArguments: 2, maxArguments: nil, flags: []),
    Command(
        name: "completion", summary: "Print a shell completion script",
        arguments: "<zsh|bash|fish>", minArguments: 1, maxArguments: 1, flags: []),
]

struct UsageError: Error {
    let message: String
    let command: String?
}

struct Parsed: Equatable {
    var flags: Set<String> = []
    var arguments: [String] = []
}

enum Invocation: Equatable {
    case help(String?)
    case version
    case run(String, Parsed)
}

func parseInvocation(_ args: [String]) throws -> Invocation {
    guard let first = args.first else { return .help(nil) }
    switch first {
    case "-h", "--help": return .help(nil)
    case "-V", "--version": return .version
    case "help":
        guard let name = args.dropFirst().first else { return .help(nil) }
        guard commands.contains(where: { $0.name == name }) else {
            throw UsageError(message: "unknown command '\(name)'", command: nil)
        }
        return .help(name)
    default: break
    }
    guard let command = commands.first(where: { $0.name == first }) else {
        throw UsageError(message: "unknown command '\(first)'", command: nil)
    }
    var parsed = Parsed()
    var optionsEnded = false
    for arg in args.dropFirst() {
        if optionsEnded || !arg.hasPrefix("-") || arg == "-" {
            parsed.arguments.append(arg)
        } else if arg == "--" {
            optionsEnded = true
        } else if arg == "-h" || arg == "--help" {
            return .help(command.name)
        } else if command.flags.contains(where: { $0.name == arg }) {
            parsed.flags.insert(arg)
        } else {
            throw UsageError(message: "unknown option '\(arg)'", command: command.name)
        }
    }
    if parsed.arguments.count < command.minArguments {
        throw UsageError(message: "missing argument, expected \(command.arguments)", command: command.name)
    }
    if let max = command.maxArguments, parsed.arguments.count > max {
        throw UsageError(message: "unexpected argument '\(parsed.arguments[max])'", command: command.name)
    }
    return .run(command.name, parsed)
}

// MARK: - Help

func usageLine(_ command: Command) -> String {
    let flags = command.flags.isEmpty ? "" : " [options]"
    let arguments = command.arguments.isEmpty ? "" : " \(command.arguments)"
    return "Usage: scheman \(command.name)\(flags)\(arguments)"
}

func helpText(for name: String?) -> String {
    guard let name, let command = commands.first(where: { $0.name == name }) else {
        let width = commands.map(\.name.count).max() ?? 0
        let lines = commands.map { "  \($0.name.padding(toLength: width, withPad: " ", startingAt: 0))  \($0.summary)" }
        return """
            Usage: scheman <command> [options]

            Commands:
            \(lines.joined(separator: "\n"))

            A <target> is a URL scheme or a file type, detected from its form:
              mailto, mailto://    URL scheme
              .md                  file extension
              text/plain           MIME type
              public.json          UTI

            An <app> is a bundle ID, an app name, or a path to a .app.

            Examples:
              scheman schemes --all
              scheman get mailto .md
              scheman set "Open in Neovim" .md .txt public.plain-text
              scheman set Firefox http https

            Run 'scheman help <command>' for command options.
            """
    }
    var options = command.flags.map { ($0.name, $0.help) } + [("-h, --help", "Show help")]
    let width = options.map(\.0.count).max() ?? 0
    options = options.map { ($0.0.padding(toLength: width, withPad: " ", startingAt: 0), $0.1) }
    return """
        \(usageLine(command))

        \(command.summary).

        Options:
        \(options.map { "  \($0.0)  \($0.1)" }.joined(separator: "\n"))\(command.name == "completion" ? "\n\n" + completionInstallHelp : "")
        """
}

let completionInstallHelp = """
    Install:
      zsh   mkdir -p ~/.zfunc && scheman completion zsh > ~/.zfunc/_scheman
            then add 'fpath=(~/.zfunc $fpath)' before 'compinit' in ~/.zshrc
            (or, without a file: 'source <(scheman completion zsh)' after 'compinit')
      bash  scheman completion bash > ~/.local/share/bash-completion/completions/scheman
            (or: 'source <(scheman completion bash)' in ~/.bashrc)
      fish  scheman completion fish > ~/.config/fish/completions/scheman.fish
    """

// MARK: - Output

func out(_ text: String) {
    print(text)
}

func err(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

func table(_ header: [String], _ rows: [[String]]) -> String {
    let all = [header] + rows
    let widths = header.indices.map { column in all.map { $0[column].count }.max() ?? 0 }
    return all.map { row in
        row.indices.map { column in
            column == row.count - 1 ? row[column] : row[column].padding(toLength: widths[column], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
    }.joined(separator: "\n")
}

func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

// MARK: - Completions

func completionScript(for shell: String) -> String? {
    let names = commands.map(\.name).joined(separator: " ")
    let appNames = "scheman apps --all --names 2>/dev/null"
    switch shell {
    case "zsh":
        let cases = commands.map { command -> String in
            let flags = command.flags.map { "'\($0.name)[\($0.help)]'" }.joined(separator: " ")
            switch command.name {
            case "set":
                return "    set) if (( CURRENT == 3 )); then local -a apps; apps=(\"${(@f)$(\(appNames))}\"); compadd -a apps; fi ;;"
            case "completion":
                return "    completion) compadd zsh bash fish ;;"
            default:
                return "    \(command.name)) _arguments \(flags.isEmpty ? "''" : flags) ;;"
            }
        }
        let descriptions = commands.map { "'\($0.name):\($0.summary)'" }.joined(separator: " ")
        return """
            #compdef scheman
            _scheman() {
              if (( CURRENT == 2 )); then
                local -a commands; commands=(\(descriptions)); _describe command commands; return
              fi
              case $words[2] in
            \(cases.joined(separator: "\n"))
              esac
            }
            if [ "$funcstack[1]" = "_scheman" ]; then _scheman "$@"; else compdef _scheman scheman; fi
            """
    case "bash":
        let cases = commands.map { command -> String in
            switch command.name {
            case "set":
                return "    set) if (( COMP_CWORD == 2 )); then local IFS=$'\\n'; COMPREPLY=($(compgen -W \"$(\(appNames))\" -- \"$cur\")); fi ;;"
            case "completion":
                return "    completion) COMPREPLY=($(compgen -W \"zsh bash fish\" -- \"$cur\")) ;;"
            default:
                return "    \(command.name)) COMPREPLY=($(compgen -W \"\(command.flags.map(\.name).joined(separator: " "))\" -- \"$cur\")) ;;"
            }
        }
        return """
            _scheman() {
              local cur=${COMP_WORDS[COMP_CWORD]}
              if (( COMP_CWORD == 1 )); then COMPREPLY=($(compgen -W "\(names)" -- "$cur")); return; fi
              case ${COMP_WORDS[1]} in
            \(cases.joined(separator: "\n"))
              esac
            }
            complete -F _scheman scheman
            """
    case "fish":
        var lines = ["complete -c scheman -f"]
        for command in commands {
            lines.append("complete -c scheman -n __fish_use_subcommand -a \(command.name) -d '\(command.summary)'")
            for flag in command.flags {
                lines.append("complete -c scheman -n '__fish_seen_subcommand_from \(command.name)' -l \(flag.name.dropFirst(2)) -d '\(flag.help)'")
            }
        }
        lines.append("complete -c scheman -n '__fish_seen_subcommand_from set; and test (count (commandline -opc)) -eq 2' -a '(\(appNames))'")
        lines.append("complete -c scheman -n '__fish_seen_subcommand_from completion' -a 'zsh bash fish'")
        return lines.joined(separator: "\n")
    default:
        return nil
    }
}
