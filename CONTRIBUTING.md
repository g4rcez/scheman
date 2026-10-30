# Contributing

Thank you for your help. `scheman` is a small Swift CLI for macOS with no dependencies. Keep it that way.

## Setup

You need macOS 13 or later and Swift 6.0 or later.

```sh
swift build
swift test
```

## Guidelines

- Open an issue before a large change.
- Keep a change focused. Do not mix refactors with behavior changes.
- Add a test for each change in behavior. Tests use [Swift Testing](https://github.com/swiftlang/swift-testing) and assert on public results with literal values.
- Do not add dependencies.
- Update `README.md` and `CHANGELOG.md` for user-visible changes.
- Keep exit codes stable: `0` ok, `1` a lookup or set failed, `64` usage error.

## Pull requests

1. Fork the repository and create a branch.
2. Run `swift test`.
3. Open a pull request and fill in the template.

By contributing, you agree that your work is under the [MIT license](LICENSE).

## Releases

Releases are automatic (`.github/workflows/release.yml`):

- A merge to `main` releases the next patch version.
- For a minor or major version, push a tag: `git tag v0.2.0 && git push origin v0.2.0`.

Each release builds a universal (arm64 and x86_64) binary, publishes it on the GitHub release, and updates `Formula/scheman.rb`.
