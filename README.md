# Obsidian Sync for iOS

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

Planning complete. The next task is the Phase 0 feasibility spike on a physical
iPad. No production code should be built until both Phase 0 gates pass.

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
