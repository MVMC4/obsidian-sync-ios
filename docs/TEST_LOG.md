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
