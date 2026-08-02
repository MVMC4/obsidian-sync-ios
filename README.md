# Obsidian Sync for iOS

[![Core checks](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/core.yml/badge.svg)](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/core.yml)
[![iOS checks](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/framework.yml/badge.svg)](https://github.com/MVMC4/obsidian-sync-ios/actions/workflows/framework.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A focused iPad/iPhone companion that joins an existing Syncthing cluster and
syncs one Obsidian vault while the app is open.

> **Development release:** physical two-way synchronization has been proven on
> an iPad, including a deletion propagated back to the desktop. Keep an
> independent backup and Syncthing file versioning enabled. This is not yet an
> App Store release or a continuously running background service.

## Start here

- **Windows PC and no Mac:** follow the complete
  [Windows → iPad → Obsidian guide](docs/WINDOWS_TO_IPAD_AND_OBSIDIAN.md).
- **Mac and Xcode:** use the [build and installation guide](docs/BUILDING.md).
- **Contribute:** read [CONTRIBUTING.md](CONTRIBUTING.md), then open an Issue or
  pull request.
- **Need help:** read [SUPPORT.md](SUPPORT.md) and the troubleshooting section
  of the complete guide.

![Vault Sync transferring an established desktop vault on a physical iPad](docs/images/vault-sync-active-session.jpg)

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
2. Configure the iPad with an existing Syncthing device and exact Folder ID.
3. Tap **Sync now** and keep the app in the foreground.
4. See an unambiguous result: up to date, syncing, conflict, permission lost,
   peer unavailable, or failed.
5. Return to Obsidian only after the sync session has stopped cleanly.

The first release is intentionally a manual, foreground-only tool. It will not
pretend that iOS can provide a continuously running Syncthing daemon.

## Current status

The real Syncthing engine, peer and vault configuration, manual scanning, and
two-sided completion checks are implemented behind a narrow Go/Swift boundary.
GitHub Actions cross-compiles the XCFramework, builds the native SwiftUI app,
runs the linked test suite on an iPad Simulator, and publishes an unsigned arm64
device IPA.

The Windows installation route has now been completed on a physical iPad using
GitHub Actions and Sideloadly. The device test proved access to a local Obsidian
vault, desktop-to-iPad transfer, iPad-to-desktop transfer, visible recent
activity, and a deletion propagated from the iPad back to the desktop. The app
records a bounded structured session history and can share a redacted report
without vault paths, device IDs, addresses, keys, or raw errors.

This proves the working prototype, not every production-hardening case. The
foreground runtime limit, interrupted transfers, conflicts, low storage,
permission revocation, very large vaults, and repeated long-term refresh cycles
remain important test and improvement areas. See [STATUS.md](STATUS.md) for the
precise boundary.

See:

- [Project plan](docs/PROJECT_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Decisions and risks](docs/DECISIONS.md)
- [Build and installation guide](docs/BUILDING.md)
- [Complete Windows to iPad to Obsidian guide](docs/WINDOWS_TO_IPAD_AND_OBSIDIAN.md)
- [Install on an iPad from Windows](docs/WINDOWS_SIDELOAD.md)
- [Build log](docs/BUILD_LOG.md)
- [Test log](docs/TEST_LOG.md)
- [Physical iPad test checklist](docs/PHYSICAL_IPAD_TEST_CHECKLIST.md)
- [Current status](STATUS.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)

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

The final native application must be compiled with Xcode and the Apple iOS SDK.
That build can run on a local Mac or on GitHub's hosted macOS runner. A Windows
PC can download the resulting unsigned IPA, apply a personal development
signature with Sideloadly, and install it on an iPad without a local Mac.

Go and `gomobile` build the embedded Syncthing framework. Xcode builds the
Swift application and runs the native tests. Android Studio cannot replace the
iOS SDK, signing, Simulator, or physical-device provisioning.

The repository will include repeatable build scripts, versioned build notes,
test results, and incremental commits as implementation progresses.

## License

Original code in this repository is available under the [MIT License](LICENSE).
Third-party dependencies retain their own licenses. In particular, Syncthing is
licensed under MPL-2.0; distributing an application that includes it must also
preserve the notices and source-code obligations that apply to that dependency.
See [third-party notices](THIRD_PARTY_NOTICES.md) for the pinned source version.

Forks, issues, and pull requests are welcome. Contributions are licensed under
the same MIT terms for original project code; see
[CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md).
