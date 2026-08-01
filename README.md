# Obsidian Sync for iOS

[![Core checks](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/core.yml/badge.svg)](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/core.yml)
[![iOS checks](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/framework.yml/badge.svg)](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/framework.yml)

A focused iPad/iPhone companion that joins an existing Syncthing cluster and
syncs one Obsidian vault while the app is open.

## Motivation

I use Obsidian across Linux, Windows, and Android, with Syncthing keeping the
same vault available on every device. Adding an iPad exposed the missing piece:
Syncthing has no official iOS client, while the available approaches have often
been paid, limited, or unsuitable for the simple workflow I wanted.

So I decided to build my own free and open-source iOS alternative.

The objective is deliberately straightforward: open the app, synchronize the
vault directly with existing Syncthing devices, verify that the files are up to
date, and return to Obsidian. No hosted account and no proprietary sync service
are required.

## Product promise

1. Pick an Obsidian vault through the iOS folder picker.
2. Pair the iPad with an existing Syncthing device.
3. Tap **Sync now** and keep the app in the foreground.
4. See an unambiguous result: up to date, syncing, conflict, permission lost,
   peer unavailable, or failed.
5. Return to Obsidian only after the sync session has stopped cleanly.

The first release is intentionally a manual, foreground-only tool. It will not
pretend that iOS can provide a continuously running Syncthing daemon.

## Current status

The real Syncthing engine, peer and vault configuration, and manual scanning are
implemented behind a narrow Go facade. A native SwiftUI vault-access spike now
compiles and passes automated tests on an iPad Simulator. The real Go core is
cross-compiled as an XCFramework, linked into the Swift app, and exercised from
Swift through a complete start/stop cycle. The app now includes persistent peer
and folder settings, a bounded foreground sync-session controller, two-sided
completion checks, cancellation, and a functional native dashboard. The next
gating task is to run it against a disposable Obsidian vault and real desktop
peer on a physical iPad; a Simulator cannot prove cross-app folder permission or
real network-transfer behavior.

See:

- [Project plan](docs/PROJECT_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Decisions and risks](docs/DECISIONS.md)
- [Build and installation guide](docs/BUILDING.md)
- [Build log](docs/BUILD_LOG.md)
- [Test log](docs/TEST_LOG.md)
- [Current status](STATUS.md)

## Repository layout

```text
app/       Swift/SwiftUI iOS application
core/      Go wrapper around upstream Syncthing
docs/      Architecture, plan, and decisions
scripts/   Repeatable build and verification commands
tests/     Cross-component and device test material
```

## Working name

`obsidian-sync-ios` is a repository name, not a final product name. Avoid using
Obsidian or Syncthing trademarks in a public app name until branding and store
requirements have been reviewed.

## Development requirements

The final application must be compiled and signed on macOS with Xcode. Go and
`gomobile` build the embedded Syncthing framework, while Xcode builds, signs,
installs, and debugs the Swift application on an iPhone or iPad. Android Studio
cannot produce or install the final native iOS application by itself.

The repository will include repeatable build scripts, versioned build notes,
test results, and incremental commits as implementation progresses.

## License

Original code in this repository is available under the [MIT License](LICENSE).
Third-party dependencies retain their own licenses. In particular, Syncthing is
licensed under MPL-2.0; distributing an application that includes it must also
preserve the notices and source-code obligations that apply to that dependency.
See [third-party notices](THIRD_PARTY_NOTICES.md) for the pinned source version.
