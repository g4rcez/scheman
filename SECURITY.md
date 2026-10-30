# Security policy

## Reporting a vulnerability

Do not open a public issue. Use GitHub's
[private vulnerability reporting](../../security/advisories/new) for this repository.
Include the version (`scheman --version`), the macOS version, and the steps to reproduce.

## Scope

`scheman` changes which app opens a URL scheme or file type for the current user.
It does not need elevated privileges, does not use the network, and does not run other programs.
