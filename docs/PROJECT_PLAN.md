# Staged project plan

## 1. Goal and boundaries

### Goal

Deliver a personal iOS/iPadOS app that acts as a real Syncthing node and safely
synchronizes one user-selected Obsidian vault on demand.

### MVP boundaries

- One vault.
- One or more already-running desktop Syncthing peers.
- Send-and-receive mode.
- Manual foreground sessions.
- Local network first; global discovery and relays only after local sync works.
- Sideloaded development build first; App Store distribution is a later choice.

### Non-goals for the MVP

- Guaranteed continuous or scheduled background synchronization.
- A complete clone of Syncthing's web UI.
- A new implementation of the Block Exchange Protocol.
- File Provider extension, selective sync, media streaming, or photo backup.
- Multiple vaults, teams, accounts, or a hosted cloud service.

## 2. Phase 0 — prove the two hard assumptions

This phase prevents weeks of UI work around an invalid filesystem or build
assumption.

### Gate A: Obsidian vault access spike

Build a minimal Swift app with a folder picker. On a physical iPad:

1. Select `On My iPad -> Obsidian -> <vault>`.
2. Retain the returned security-scoped URL only for the active operation.
3. Save bookmark data in the app's Application Support directory.
4. Use `NSFileCoordinator` for the spike's reads and writes.
5. Create a nested Markdown file, read it, edit it, rename it, and delete it.
6. Kill and relaunch the app, resolve the bookmark, and repeat the test.
7. Open Obsidian and confirm its file index observes each change.
8. Revoke Files and Folders permission and confirm the app reports a recoverable
   permission error instead of crashing.

Pass criteria: recursive write access survives relaunch, changes are visible in
Obsidian, and failure is clean when permission is revoked.

Important correction to the original draft: current Apple iOS directory-picker
guidance demonstrates saving a minimal bookmark and requires handling stale or
revoked access. Do not copy macOS-only bookmark entitlement assumptions into the
iOS target.

### Gate B: embedded Syncthing build spike

On macOS:

1. Create a tiny Go package that imports `github.com/syncthing/syncthing/lib/syncthing`.
2. Expose only bindable primitive methods such as `Start`, `Stop`, `DeviceID`,
   `StatusJSON`, and `LastError`.
3. Pin the Syncthing and Go versions.
4. Build an XCFramework for iOS device and simulator with `gomobile bind`.
5. Start and stop the engine from a blank Swift app on a physical iPad.
6. Store Syncthing config, certificate, key, logs, and database under the app's
   Application Support directory.

Pass criteria: the framework builds reproducibly, starts without forbidden
runtime behavior, returns a stable device ID after relaunch, and stops cleanly.

### Phase 0 decision

- Both gates pass: continue with the architecture below.
- Folder access fails: stop and choose a storage pivot before writing the app.
- Engine embedding fails: inspect Sushitrain's current build approach and patch
  the wrapper; do not reimplement the Syncthing protocol.

## 3. Phase 1 — repository and build foundation

### Work

- Create an Xcode SwiftUI app under `app/`.
- Create the Go module under `core/`.
- Add a Makefile or script that produces a versioned XCFramework.
- Add Debug/Release configuration without committing signing identities.
- Add CI checks that can run without signing: Go tests, `go vet`, Swift format,
  and simulator compilation where available.
- Record exact Xcode, iOS SDK, Go, gomobile, and Syncthing versions.

### Done when

A clean macOS checkout can build the Go framework and compile the iOS app using
one documented command plus Xcode signing configuration.

## 4. Phase 2 — a narrow Go engine facade

### Responsibilities

- Generate or load the Syncthing device certificate and identity.
- Generate or load configuration and database.
- Start and stop one in-process `syncthing.App` instance.
- Add/update/remove peer and folder configuration.
- Request scans and expose connection, folder, completion, and error state.
- Convert complex Go values to JSON strings or deliberately tiny bindable DTOs.
- Emit coarse events to Swift without blocking Syncthing goroutines.

### Initial facade

```text
NewClient(statePath) -> Client
Client.Start() -> error
Client.Stop() -> error
Client.DeviceID() -> string
Client.ConfigurePeer(deviceID, name, addressesJSON) -> error
Client.ConfigureFolder(folderID, folderPath, label) -> error
Client.Scan(folderID) -> error
Client.StatusJSON() -> string
Client.SetDelegate(delegate)
```

The exact signatures may change during the spike. The rule is that Swift never
depends directly on Syncthing's unstable internal Go types.

### Done when

Go unit tests cover lifecycle, persistent identity, invalid configuration,
idempotent start/stop handling, and status serialization.

## 5. Phase 3 — vault permission subsystem

Create a Swift `VaultAccessCoordinator` as the only component allowed to own a
selected vault URL or bookmark.

### Responsibilities

- Present a folder-only `UIDocumentPickerViewController`.
- Validate that the selection looks like an Obsidian vault without requiring
  `.obsidian` to exist for a brand-new vault.
- Save bookmark data outside `UserDefaults`, with schema/version metadata.
- Resolve stale bookmarks and prompt for reselection when necessary.
- Balance every successful `startAccessingSecurityScopedResource()` call with
  exactly one stop call.
- Hold access for the complete engine session, then release it.
- Surface typed errors: not selected, stale, revoked, unavailable, read-only.
- Investigate file coordination under sustained Go POSIX I/O and document the
  result from physical-device testing.

### Done when

Automated Swift tests cover bookmark state transitions, and device tests prove
relaunch and permission-recovery behavior.

## 6. Phase 4 — manual sync session state machine

Treat a sync as a bounded session, not a daemon.

```text
idle
  -> acquiringVaultAccess
  -> startingEngine
  -> discoveringOrConnecting
  -> scanning
  -> synchronizing
  -> verifyingCompletion
  -> stoppingEngine
  -> releasingVaultAccess
  -> complete | failed | cancelled
```

### Rules

- Only one session may run at a time.
- A session has cancellation and a maximum idle timeout.
- Losing foreground begins orderly shutdown by default.
- A short `UIApplication` background task may be used only to finish shutdown or
  already-user-initiated cleanup; it is not a daemon loophole.
- “Up to date” requires the folder to be idle, peer completion to be current,
  and no outstanding errors or conflict files.
- The app must never tell the user to open Obsidian while the engine still owns
  an active write operation.

### Done when

The UI can start, cancel, and finish a real two-device sync and always returns to
a stable state after interruption, networking loss, or app backgrounding.

Implementation status: the state machine, timeout, cancellation, stable-result
verification, and cleanup paths are implemented and Simulator-tested. The real
two-device and background-transition matrix remains pending on physical hardware.

## 7. Phase 5 — onboarding and minimum UI

### Screens

1. **Welcome:** explains manual foreground syncing and privacy.
2. **Choose vault:** picker, current folder name, and permission test.
3. **Pair device:** show this device ID/QR; enter or scan the desktop device ID.
4. **Accept folder:** map the remote folder ID to the selected vault path.
5. **Sync:** large action button, peer state, progress, recent files, and result.
6. **Diagnostics:** export redacted logs and configuration summary.

Implementation status: the functional sync dashboard, vault picker, manual
pairing/settings sheet, live progress, result states, and vault diagnostics are
implemented. Persistent structured session diagnostics and redacted JSON export
are also implemented and Simulator-tested. QR display, scanning UI, camera
permission handling, and upstream device-ID checksum validation are implemented;
physical camera capture remains a device test. Recent-file details and final
visual styling remain pending.

### UX safety

- Use “Peer offline” instead of an endless spinner.
- Make “Stop sync” explicit before switching to Obsidian.
- Explain conflict filenames and link directly to the vault in Files when
  possible.
- Never expose certificate private keys, API keys, or unredacted filesystem paths
  in shared diagnostics.

## 8. Phase 6 — data integrity and conflict hardening

### Test matrix

- Markdown create/edit/delete/rename on every device.
- Simultaneous edits while the iPad is offline.
- `.obsidian` configuration and plugin files.
- Unicode, emoji, long names, nested paths, and zero-byte files.
- Attachments large enough to interrupt mid-transfer.
- Low storage, locked device, Wi-Fi loss, peer restart, force quit, and stale
  bookmark.
- Syncthing conflict copies and versioning behavior.
- Upgrade from one pinned Syncthing version to the next with the same database.

Use a disposable test vault and backups until the release candidate passes the
matrix. Never make the user's only vault the first integration test.

### Done when

Repeated fault-injection tests produce no silent loss, the app explains all
recoverable states, and a backup/restore drill has been completed.

## 9. Phase 7 — optional background conveniences

Only after foreground sync is reliable:

- Add a Shortcuts/App Intent action for “Sync selected vault.”
- Evaluate `BGProcessingTask` as opportunistic best effort, never as a schedule.
- Use local notifications for completion or required attention.
- Evaluate newer continued-processing APIs only if the minimum iOS version and
  App Review rules fit the project.

Success here means “sometimes more convenient,” not continuous Syncthing parity
with Linux or Windows.

## 10. Phase 8 — distribution and maintenance

### Personal use

- Xcode run with a free Apple ID is suitable for early device testing but may
  require frequent re-signing.
- A paid Apple Developer membership is the practical route for durable personal
  builds and TestFlight/App Store distribution.

### Maintenance

- Pin upstream Syncthing; upgrade intentionally, one version at a time.
- Track MPL-2.0 notices and source obligations for modified MPL files.
- Add a privacy manifest and complete required-use API declarations as needed.
- Review names, icons, and store metadata for Obsidian and Syncthing trademarks.
- Maintain an upgrade fixture containing old config and database state.

## 11. Recommended implementation order

1. Physical-iPad vault access spike.
2. Physical-iPad embedded-engine spike.
3. One hard-coded peer and one disposable vault end-to-end.
4. Lifecycle and cancellation correctness.
5. Pairing and onboarding UI.
6. Error recovery and conflict visibility.
7. Test matrix and backups.
8. Optional conveniences and distribution.

The first meaningful milestone is not a polished screen. It is a disposable
Markdown file that travels Windows/Linux -> iPad -> Windows/Linux without loss.
