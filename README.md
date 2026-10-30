# scheman

[![CI](https://github.com/g4rcez/scheman/actions/workflows/ci.yml/badge.svg)](https://github.com/g4rcez/scheman/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-lightgrey)

Swift CLI to list and set default apps for URL schemes and file types on macOS. Replaces `duti`. No dependencies.

## Install

Homebrew:

```sh
brew tap g4rcez/scheman https://github.com/g4rcez/scheman
brew install scheman
```

Prebuilt universal binaries are on the [releases page](https://github.com/g4rcez/scheman/releases). From source:

```sh
swift build -c release
cp "$(swift build -c release --show-bin-path)/scheman" ~/.local/bin/
scheman completion zsh > ~/.zfunc/_scheman   # see "scheman help completion"
```

## Usage

```sh
scheman schemes [--all] [--json]     # scheme -> default app (--all: every app that can handle it)
scheman apps [--all] [--json]        # apps that declare URL schemes (--all: every app)
scheman get <target>...              # default app and all apps for each target
scheman set <app> <target>...        # set the default app
```

- `<target>` is detected from its form: `mailto` (URL scheme), `.md` (extension), `text/plain` (MIME), `public.json` (UTI).
- `<app>` is a bundle ID, an app name, or a path to a `.app`.
- There is no role argument: the handler applies to all roles (same as `duti ... all`).
- Exit codes: `0` ok, `1` a lookup or set failed, `64` usage error.

```sh
scheman set "Open in Neovim" .md .txt public.plain-text
scheman set Firefox http https
```

## duti migration

| duti | scheman |
|---|---|
| `duti -s com.app .md all` | `scheman set com.app .md` |
| `duti -d public.html` | `scheman get public.html` |
| `duti -l mailto` | `scheman get mailto` |
| `duti -x md` | `scheman get .md` |
| settings file / stdin | not supported; pass many targets to `set` |

## Limits

- No public API lists all URL schemes. `schemes` and `apps` read `Info.plist` files under `/Applications`, `~/Applications`, `/System/Applications`, and `/System/Library/CoreServices` (3 levels deep). Apps elsewhere appear as handlers, not as declarers.
- Setting `http`/`https` shows a macOS confirmation dialog.

## Test

```sh
swift test
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report security issues as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
