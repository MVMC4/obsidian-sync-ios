# Test log

This log distinguishes source checks, automated tests, Simulator tests, and
physical-device tests. “Not run” is preferable to claiming coverage that does
not exist.

## 2026-08-01 — Repository baseline checks

- `git diff --check`: passed before the initial commit
- Required planning files: present
- MIT license text: present
- Prohibited tool attribution in repository text: none found
- Go tests: not run; no Go module yet
- Swift tests: not run; no Xcode project yet
- iPad folder-access test: not run; requires the Phase 0 device spike

## 2026-08-01 — Mobile core lifecycle tests

- Host: Windows amd64
- Go: 1.25.12
- `go test ./...`: passed
- `go vet ./...`: passed
- `go test -cover ./...`: passed
- Statement coverage: 74.2%
- Covered behavior: initial state, idempotent engine start/stop, start failure,
  missing engine handling, and versioned primitive JSON status
- Not covered yet: real Syncthing lifecycle, filesystem/database state,
  gomobile bindings, Swift integration, and physical-device behavior

## 2026-08-01 — Initial remote CI

- Revision: `370d924`
- GitHub Actions `Core checks`: passed
- `gofmt` check: passed
- `go vet ./...`: passed
- `go test -race -coverprofile=coverage.out ./...`: passed
- Statement coverage: 74.2%
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30691040646

## 2026-08-01 — Real Syncthing adapter tests

- `TestNewClientPersistsSyncthingIdentity`: passed
- `TestRealSyncthingEngineStartsAndStops`: passed
- Full `go test -tags noassets -cover ./...`: passed
- `go vet -tags noassets ./...`: passed
- Local statement coverage: 74.3%
- One default build attempt failed because upstream generated web assets were
  absent; all commands now consistently use the correct `noassets` build tag
- Local `-race` attempt was not runnable because CGO is disabled on this Windows
  toolchain; race-enabled verification is delegated to GitHub Actions on Ubuntu
- Remote `go test -tags noassets -race -coverprofile=coverage.out ./...`: passed
- Remote statement coverage: 74.3%
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30691765411

## 2026-08-01 — Peer and vault configuration tests

- Full `go test -tags noassets -cover ./...`: passed
- `go vet -tags noassets ./...`: passed
- Statement coverage: 75.8%
- Covered: address parsing defaults and errors, peer configuration, vault-folder
  configuration, manual watcher policy, explicit scan, and runtime persistence
- The first remote race-enabled run failed in the upstream QUIC/STUN shutdown
  path and exposed a deferred configuration save outliving the test state path
- Remediation assertions cover the TCP-only listener and disabled NAT/STUN
- `go test -tags noassets -count=5 ./...`: passed locally
- Local statement coverage after remediation: 76.9%
- Remote `go test -tags noassets -race -coverprofile=coverage.out ./...`: passed
- Passing run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692178161

## 2026-08-01 — Native vault-access spike tests

- Host: iPad Pro 11-inch (M4) Simulator, iOS 18.5, Xcode 16.4
- `VaultBookmarkStoreTests`: passed
- `VaultSpikeRunnerTests`: passed
- Covered: versioned bookmark-record persistence, clear behavior, rejection of
  unknown schemas, coordinated create/read/edit/rename/delete operations, and
  cleanup of the temporary test directory
- The first test attempt did not launch because the generated test-host product
  path was inconsistent; app compilation passed in that run
- Corrected run: passed in 2 minutes 31 seconds
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692783055
- Physical iPad folder-picker, relaunch, permission revocation, and Obsidian
  visibility tests: not run

## 2026-08-01 — Swift-to-Go integration test

- Revision: `31e0c17`
- `SyncthingBridgeTests.testEmbeddedEngineCreatesIdentityStartsAndStops`: passed
- Environment: iPad Pro 11-inch (M4) Simulator, iOS 18.5, Xcode 16.4
- Covered: Objective-C binding import, app-private engine-state directory,
  certificate/device identity generation, Swift-to-Go lifecycle calls, running
  state, orderly shutdown, and stopped state
- Full linked iOS workflow: passed in 3 minutes 56 seconds
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30694852522
- Physical iPad engine lifecycle and networking: not run

## 2026-08-01 — Manual sync-session tests

- Go folder-status integration test: passed locally and under the Ubuntu race
  detector
- `SyncProfileStoreTests`: passed
- `SyncSessionControllerTests`: passed
- Covered: profile normalization and persistence, dynamic-address defaults,
  peer/folder configuration order, scan request, disconnected-peer handling,
  two consecutive complete samples, timeout without false success, engine stop,
  and exactly-once vault release after success or failure
- Native dashboard and all prior Swift tests: passed on iPad Pro 11-inch (M4)
  Simulator with iOS 18.5 and Xcode 16.4
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695630517
- Real desktop-to-iPad transfer, conflict, interruption, and Obsidian visibility:
  not run; these remain physical-device gates

## 2026-08-01 — Repeat-session and conflict tests

- `SyncthingBridgeTests`: two complete start/stop cycles passed with the same
  persistent device ID
- `SyncSessionControllerTests`: repeated clean sessions and conflict-attention
  terminal state passed
- `VaultConflictScannerTests`: relative-path detection, ordinary-file exclusion,
  deterministic sorting, and result cap passed
- All native tests passed on iPad Pro 11-inch (M4) Simulator with iOS 18.5
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695851603
- Local Network permission prompt and actual LAN traffic: not testable in this
  automation and still require the physical checklist

## 2026-08-01 — Real bidirectional protocol transfer

- Revision: `9964828`
- `TestBidirectionalSyncthingTransfer`: passed on Ubuntu under the race detector
- Topology: parent test process plus a helper test process, with independent
  certificates, device IDs, configuration directories, databases, listeners,
  and vault directories
- Outbound verification: the helper received `from-ipad.md` with exact expected
  contents
- Inbound verification: the parent received `from-desktop.md` with exact
  expected contents
- Determinism: explicit loopback TCP addresses; discovery, relays, and NAT
  traversal disabled only for the integration nodes
- `go test -tags noassets -race -coverprofile=coverage.out ./...`: passed
- Statement coverage: 77.0%
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696198329
- Full linked iOS Simulator regression: passed
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696198311
- Still not proven by automation: security-scoped access to Obsidian's physical
  iPad folder, the Local Network permission prompt, real Wi-Fi conditions,
  background interruption, and Obsidian visibility after transfer

## 2026-08-01 — Structured diagnostics and redaction tests

- Revision: `42def5c`
- `DiagnosticsTests.testEventStoreRoundTripsAndKeepsNewestEntries`: passed
- `DiagnosticsTests.testReportIncludesUsefulStateWithoutSensitiveConfiguration`:
  passed
- `DiagnosticsTests.testRecorderPersistsOnlyStructuredEvents`: passed
- `DiagnosticsTests.testExportWriterProducesExpectedJSONFile`: passed
- Session-controller success and configuration-failure tests now also verify
  the recorded terminal outcome
- Covered: bounded persistent event history, ISO-8601 round trip, exact export
  filename/content, useful connection/progress/conflict fields, unknown-state
  normalization, and omission of device IDs, peer names, addresses, folder IDs,
  labels, and filesystem paths
- Full iPad Simulator suite: passed
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696817304
- Physical share-sheet behavior and inspection of a report produced after a
  real device session: not run; added to the physical verification gate

## 2026-08-01 — QR pairing and startup-race tests

- Revision: `81e3979`
- Go `TestNormalizeDeviceID`: passed; verifies trimming, lowercase-to-canonical
  conversion, upstream check digits, empty rejection, and malformed rejection
- Swift `PairingQRCodeTests`: passed; verifies trimmed parser input, canonical
  output, empty/foreign payload rejection, and square visible QR generation
- Swift `SyncthingBridgeTests.testDeviceIDNormalizationUsesSyncthingChecksums`:
  passed through the generated Objective-C binding
- Camera scanner, preview overlay, denied/restricted/unavailable messages, and
  `NSCameraUsageDescription` compile in the linked app
- The initial race-enabled run exposed a transient `folder is not running`
  result between config commit and folder-service readiness
- `TestScanWhenFolderReadyRetriesTransientFailure`: passed
- Corrected two-process bidirectional transfer: passed under the race detector
- Statement coverage: 77.4%
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697607940
- Full linked iPad Simulator suite: passed
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697607944
- Physical camera authorization, live capture, desktop scanning of the iPad QR,
  and iPad scanning of the desktop QR: not run; added to the physical checklist

## 2026-08-01 — Completed interface regression

- Revision: `69d9475`
- Corrected `SyncActivityItem` to expose its existing content-derived stable
  identity through Swift's `Identifiable` contract
- Added a model assertion that the SwiftUI identity remains equal to the
  deduplication identity
- Local `go vet -tags noassets ./...`: passed
- Local `go test -tags noassets -count=1 -coverprofile coverage.out ./...`:
  passed with 79.6% statement coverage
- Ubuntu Core checks, including `-race`: passed
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30710848626
- Full linked app build and native test suite on an iPad Simulator: passed
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30710848621
- Physical iPad folder access, camera, LAN transfer, Obsidian visibility, and
  signing: not run and not represented by the Simulator result

## 2026-08-01 — First-run transparency and scan-readiness regression

- Revision: `67afc03`
- Ubuntu Core checks: passed, including formatting, vet, unit/integration tests,
  coverage, and race detection
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30717953959
- macOS iOS checks: passed; the linked application compiled and the complete
  native Swift suite ran on an iPad Simulator
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30717953961
- Added coverage proving that a newly configured folder's transient scan
  readiness failures are retried before the session is failed
- Added recovery coverage proving that an unreachable peer remains actionable
  after the session enters its terminal failure state
- Verified in the compiled UI: saved settings are not presented as a verified
  pairing, setup actions confirm their result, and redacted session events are
  readable in Settings
- Physical LAN transfer and Obsidian visibility remain to be run with the new
  build and a disposable vault

## 2026-08-02 — Physical Windows-to-iPad bidirectional verification

### Environment

- Source revision installed: `67afc03`
- Build source: GitHub-hosted macOS runner
- Windows installer: Sideloadly 0.60
- Target: physical iPad over USB
- Sync topology: existing desktop Syncthing folder shared to an iPad vault

### Passed on physical hardware

- Downloaded the unsigned IPA artifact on Windows and installed it with Sideloadly.
- Trusted the Apple developer profile, launched Vault Sync, and granted Files access.
- Saved the desktop device ID and exact Syncthing folder ID.
- Observed a real peer connection, foreground progress, and incoming Recent activity.
- Received the existing desktop vault on iPad.
- Opened synchronized vault content from Obsidian on iPad.
- Created and edited a Markdown file on iPad; the change reached the laptop.
- Deleted that test file on iPad; the deletion reached the laptop.

This is direct physical proof that the configured folder operates in both directions
and that deletions propagate. It must therefore be treated as synchronization, not as
a backup mechanism.

### Findings

- A vault placed directly under `On My iPad` was not selectable as an Obsidian vault.
  Obsidian access works when the vault is created or copied under
  `On My iPad/Obsidian/<VaultName>` and selected there.
- Adding the vault to Files Favorites makes repeated selection easier.
- Foreground progress occasionally appeared stalled and then resumed. The engine has
  a bounded foreground session, so large transfers may require another session.

### Evidence

- `docs/images/vault-sync-active-session.jpg`
- `docs/images/vault-sync-recent-activity.jpg`
- `docs/images/obsidian-vault-on-ipad.jpg`

### Still unverified

- simultaneous-edit conflict behavior
- revoked Files permission and low-storage recovery
- interruption during a large attachment transfer and checksum recovery
- app termination, foreground resume, restart, and bookmark restoration
- 10,000-file and 250 MB scale targets
- multiple seven-day free-signing refresh cycles
