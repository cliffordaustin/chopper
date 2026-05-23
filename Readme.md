# Chopper

A native macOS HTTP client for testing and building APIs. Local-first, file-based, no account required.

> ⚠️ **Early development.** Not yet ready for daily use. Star the repo to follow along.

## Why Chopper?

The HTTP client space has changed in ways most developers don't love:

- **Postman** has gone cloud-first, requires an account, and pushes features most individual developers don't need.
- **Insomnia** went cloud-first under Kong, frustrating its open-source community.
- **Paw** was acquired and is no longer what it was.
- **Bruno** is great and open source, but it's Electron, not native.

Chopper is the answer to a simple question: *what if there was a Mac-native HTTP client that was open source, local-first, and built for individual developers?*

## Principles

- **Truly native.** Built in Swift and SwiftUI. No Electron, no web views pretending to be desktop apps.
- **Local-first.** No account required. No forced cloud sync. Your data stays on your machine.
- **File-based.** Collections live as plain JSON files on disk — easy to read, easy to version control, easy to share.
- **macOS Keychain integration.** Secrets and tokens are stored securely using the system Keychain, not in plain files.
- **Focused.** Chopper does HTTP testing well. It will not become a platform.

## Status

Currently building Phase 1

## Building from source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/cliffordaustin/chopper.git
cd chopper
open Chopper.xcodeproj
```

## Contributing

Contributions are welcome once Phase 1 is stable. For now, feel free to open issues with ideas or feedback.

## License

[MIT](./LICENSE)