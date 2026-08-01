# Build log

This is an append-only summary of meaningful build attempts. Detailed CI logs
will remain attached to their corresponding workflow runs.

## 2026-08-01 — Repository baseline

- Host: Windows
- Revision: `ccbb8b8`
- Result: repository initialized successfully
- Verified: Git metadata, documentation structure, MIT license, clean working
  tree after commit
- Not attempted: Go core, XCFramework, Xcode, Simulator, or physical-device build
- Reason: application and Go modules have not yet been scaffolded; Xcode requires
  a Mac

## 2026-08-01 — Mobile core lifecycle scaffold

- Host: Windows amd64
- Go: 1.25.12
- Result: Go package compiled successfully during test and vet runs
- Verified: `gofmt`, `go test ./...`, `go vet ./...`
- Not attempted: Syncthing dependency integration, gomobile binding, XCFramework,
  Xcode, Simulator, or physical-device build
- Note: an initial coverage command was run from the repository root and failed
  because the Go module is under `core/`; it was rerun from the correct module
  directory and passed

## 2026-08-01 — Initial GitHub Actions verification

- Host: GitHub-hosted Ubuntu runner
- Revision: `370d924`
- Workflow: `Core checks`
- Result: passed in 28 seconds
- Verified: checkout, Go setup, formatting, vet, race-enabled tests, and coverage
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30691040646

## 2026-08-01 — Real Syncthing adapter

- Host: Windows amd64
- Go: 1.25.12
- Syncthing: upstream `v2.1.1` release commit, represented by Go pseudo-version
  `v1.30.0-rc.1.0.20260525132207-6be1ff848028`
- Result: compiled and started a real in-process Syncthing node, then completed
  an orderly shutdown
- Runtime exercised: certificate generation, persistent device ID, configuration,
  SQLite database, discovery, relay service, TCP and QUIC listeners
- Required build tag: `noassets`, because the native application disables and
  excludes Syncthing's generated web UI
- Local race detector: not available because this Windows toolchain has CGO
  disabled; the Ubuntu CI job remains the race-enabled verification environment

### Clean CI verification

- Revision: `353e77e`
- Result: passed in 2 minutes 15 seconds
- Verified from a clean Ubuntu runner: formatting, vet, real engine lifecycle,
  race detector, and coverage
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30691765411

## 2026-08-01 — Peer and vault configuration slice

- Host: Windows amd64
- Go: 1.25.12
- Result: passed
- Implemented: validated peer device IDs and address JSON, send-receive vault
  mapping, mobile-oriented manual scan settings, and explicit scan requests
- Verified: real engine start, runtime configuration commit, vault scan, and
  orderly shutdown

### Remote race-detector failure

- Revision: `8acf427`
- Result: failed during `TestRealEngineConfiguresPeerFolderAndScan`
- Finding: the upstream QUIC/STUN service raced during shutdown; the config
  wrapper also attempted its deferred save after the test state directory was
  released
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30691951625

## 2026-08-01 — Deterministic engine shutdown

- Host: Windows amd64 and GitHub-hosted Ubuntu runner
- Revision: `2a1c2b8`
- Result: passed
- Change: constrained the foreground MVP transport listener to TCP, disabled
  NAT/STUN, and waited for configuration and event services to terminate
- Verified locally: format, vet, coverage, and five consecutive integration-test
  cycles
- Verified remotely: format, vet, race detector, real engine integration, and
  coverage
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692178161

## 2026-08-01 — Native vault-access spike

- Host: GitHub-hosted macOS 15 runner
- Xcode: 16.4
- Simulator SDK: iOS 18.5
- Revision: `3697dbc`
- Result: generated the Xcode project and compiled the unsigned native app in 30
  seconds
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692412836

### Initial test-host failure

- Revision: `e4b0f94`
- Result: app compilation passed, but tests did not launch
- Finding: a custom internal product name disagreed with XcodeGen's generated
  unit-test host path
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692454987

### Clean Simulator build and test

- Revision: `5a8b29b`
- Result: passed in 2 minutes 31 seconds
- Verified: project generation, unsigned app compilation, app installation into
  an iPad Pro 11-inch (M4) Simulator, and native unit tests
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692783055
