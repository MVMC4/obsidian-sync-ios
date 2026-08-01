# Project status

## Active phase

Software implementation complete; physical-iPad transfer gate in progress.

## Completed

- Project architecture, risks, build workflow, and test workflow documented.
- Repository licensed under MIT and prepared for public development.
- Platform-neutral Go lifecycle facade implemented.
- Go lifecycle tests and vet checks passing on Windows with Go 1.25.12.
- Released Syncthing `v2.1.1` engine embedded with persistent identity.
- Peer, vault-folder, and explicit scan configuration implemented and tested.
- Native SwiftUI folder picker and persistent bookmark subsystem implemented.
- Coordinated vault create/read/edit/rename/delete spike implemented.
- Unsigned app build and unit tests passing on an iPadOS 18.5 Simulator.
- Pinned `gomobile` build produces device and Simulator XCFramework slices.
- Swift bridge creates a persistent device identity and starts/stops the real
  embedded engine in an iPadOS Simulator test.
- Versioned folder status reports connection, local need, remote need, folder
  state, completion percentages, and a conservative up-to-date decision.
- Persistent peer/folder profile and bounded foreground sync state machine
  implemented with cleanup, cancellation, timeout, and stable-result tests.
- Functional SwiftUI dashboard supports vault selection, pairing, settings,
  sync start/stop, two-sided progress, and permission diagnostics.
- Local Network permission declaration, repeat-session identity verification,
  and bounded conflict-copy reporting implemented and Simulator-tested.
- A two-process integration test now proves exact-content transfer in both
  directions between independent embedded Syncthing nodes over TCP. The test
  passes on Ubuntu with the race detector enabled.
- Persistent, bounded session diagnostics and a shareable redacted JSON report
  are implemented and Simulator-tested. Reports exclude vault names and paths,
  device IDs, peer labels, folder IDs, addresses, keys, and raw errors.
- Pairing now displays this device's canonical ID as a QR code and can scan the
  plain device-ID QR produced by Syncthing. The pinned Go parser validates check
  digits before settings are saved; camera denial retains manual entry.
- The final activity-list identity correction is verified by Core checks run
  `30710848626` and iOS checks run `30710848621` at revision `69d9475`.
- Windows sideloading, Apple device support, developer trust, and launch have
  now been proven on a physical iPad with the unsigned device artifact.
- First-run setup now distinguishes saved settings from a verified connection,
  confirms vault and computer configuration, shows a guided checklist and
  redacted session log, and retries transient folder-start scan failures. Core
  run `30717953959` and iOS run `30717953961` pass at revision `67afc03`.

## Next concrete task

Install revision `67afc03` on the connected iPad and use a disposable vault to:

1. lets the user select `On My iPad/Obsidian/<vault>`;
2. persists and resolves the returned bookmark;
3. creates, reads, edits, renames, and deletes a nested test file;
4. repeats those operations after terminating and relaunching the app; and
5. verifies that Obsidian sees the changes.

The app has already been signed, installed, trusted, and launched on physical
hardware. The remaining gate is executing folder access and real two-way LAN
transfer against a disposable vault and a Windows or Linux Syncthing peer. Follow
`docs/PHYSICAL_IPAD_TEST_CHECKLIST.md` and record the exact environment/results.

## Exit condition

Do not start the full UI until the vault-access and embedded-engine gates in
Phase 0 of `docs/PROJECT_PLAN.md` both pass on a physical iPad.

## Known constraints

- The final iOS build requires macOS, Xcode, signing, and a physical iPad.
- Foreground manual sync is the reliable baseline.
- Bookmark access can be revoked or become stale.
- Syncthing metadata and identity must live in this app's own container, never
  inside the Obsidian vault.
