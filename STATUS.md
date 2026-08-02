# Project status

## Active phase

Working physical prototype; documentation complete and production hardening remains.

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
- Swift bridge creates a persistent device identity and starts/stops the real embedded
  engine in an iPadOS Simulator test.
- Versioned folder status reports connection, local need, remote need, folder state,
  completion percentages, and a conservative up-to-date decision.
- Persistent peer/folder profile and bounded foreground sync state machine implemented
  with cleanup, cancellation, timeout, and stable-result tests.
- Functional SwiftUI dashboard supports vault selection, pairing, settings, sync
  start/stop, two-sided progress, and permission diagnostics.
- Local Network permission declaration, repeat-session identity verification, and
  bounded conflict-copy reporting implemented and Simulator-tested.
- A two-process integration test proves exact-content transfer in both directions
  between independent embedded Syncthing nodes over TCP and passes under the race
  detector on Ubuntu.
- Persistent session diagnostics and a shareable redacted JSON report are implemented
  and Simulator-tested.
- Pairing displays this device's canonical ID as a QR code and scans the plain device-ID
  QR produced by Syncthing; manual entry remains available.
- Core and iOS checks passed for revision `67afc03`.
- A GitHub-built unsigned IPA was installed from Windows with Sideloadly 0.60; no
  locally owned Mac was required.
- The iPad trusted the developer profile and granted a persistent Files bookmark.
- The desktop peer connected and the existing desktop folder synchronized to iPad.
- Incoming desktop files appeared in Recent activity and opened in Obsidian on iPad.
- A Markdown file created and edited on iPad synchronized back to the laptop.
- Deleting that test file on iPad removed it on the laptop, proving physical
  bidirectional `Send & Receive` behavior, including delete propagation.
- The complete Windows-to-iPad, Obsidian-folder, Favorites, backup, update, and
  troubleshooting workflow is documented in
  `docs/WINDOWS_TO_IPAD_AND_OBSIDIAN.md`.

## Next concrete tasks

The physical feasibility gate passed. Production hardening should now prioritize:

1. Replace or extend the fixed foreground session limit so long transfers do not
   appear to stop after roughly three minutes.
2. Improve visible stall, reconnect, throughput, and retry telemetry.
3. Add a safer guided flow for selecting or migrating a vault into
   `On My iPad/Obsidian/<VaultName>`.
4. Execute the remaining fault and scale matrix in
   `docs/PHYSICAL_IPAD_TEST_CHECKLIST.md`, especially conflicts, permission
   revocation, low storage, interruption, restart, 10,000 files, and a 250 MB file.
5. Validate Sideloadly refresh and in-place app updates over multiple seven-day free
   signing cycles.

## Exit condition

The physical iPad feasibility gate is complete: folder bookmark access, a real peer
connection, desktop-to-iPad transfer, iPad-to-desktop transfer, Obsidian visibility,
and deletion propagation were all observed on device.

Production-ready status still requires every critical physical checklist row to pass
with no data loss and no inaccessible security scope. Keep independent backups during
all development testing.

## Known constraints

- The iOS archive must be compiled on macOS, but the GitHub-hosted macOS workflow can
  do that remotely; Windows can download and sideload the unsigned IPA.
- iOS execution is foreground-only; background execution is out of current scope.
- Files access is constrained to stored security-scoped bookmarks, which can become
  stale or be revoked.
- Local API keys, Syncthing metadata, and device identity remain in the app container,
  never inside the Obsidian vault.
- Synchronization is bidirectional and deletions propagate. It is not a backup.
- A free Apple ID signing profile normally expires after seven days and must be
  refreshed; Sideloadly is a third-party installation tool.
- Current sync sessions have a bounded foreground runtime, so large transfers can
  pause and require another session.
