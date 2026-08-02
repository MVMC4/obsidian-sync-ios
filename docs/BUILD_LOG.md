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

## 2026-08-01 — Embedded iOS framework

### Initial tool-dependency failure

- Revision: `5fd73db`
- Result: failed before cross-compilation
- Finding: Go 1.25 requires `gobind` to be retained as a `go.mod` tool
  dependency for `gomobile bind`
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30692983981

### XCFramework build

- Revision: `a1a34fa`
- Host: GitHub-hosted macOS 15 runner with Xcode 16.4 and Go 1.25
- Result: passed in 2 minutes 26 seconds
- Verified: real Syncthing facade cross-compiled for iOS device and Simulator
  slices; framework artifact uploaded for seven days
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30693062923

### Swift bridge integration

- The first linked compile at revision `f01313c` exposed that the generated C
  factory requires an explicit `NSError` pointer; the framework itself built
- Corrected revision: `31e0c17`
- Result: passed in 3 minutes 56 seconds
- Verified: XCFramework generation, Swift import and linking, unsigned app
  compile, iPad Pro Simulator installation, native unit tests, persistent
  Syncthing device identity, and engine start/stop through Swift
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30694852522

## 2026-08-01 — Manual sync-session slice

### Folder status core

- Revision: `5b94846`
- Ubuntu core workflow: passed with race detection
- Verified: folder state, peer connection, local and remote need counts,
  completion percentages, JSON schema, and conservative up-to-date policy
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695135505

### Swift status bridge correction

- The first native attempt at revision `382c5c3` built the XCFramework but
  failed Swift compilation because gomobile's string-plus-error method retains
  an explicit `NSError` pointer
- Corrected revision: `af3935c`
- Result: full iOS workflow passed in 4 minutes 30 seconds
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695410985

### Functional dashboard

- Revision: `e45243f`
- Result: full iOS workflow passed in 3 minutes 33 seconds
- Verified: XCFramework, generated Xcode project, linked app, dashboard compile,
  Simulator installation, session/profile tests, and uploaded framework artifact
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695630517

## 2026-08-01 — Physical-readiness hardening

- Revision: `335d190`
- Result: full iOS workflow passed in 4 minutes 44 seconds
- Added: Local Network usage declaration, expanded desktop-sharing instructions,
  consecutive engine sessions with stable identity, coordinated conflict-copy
  scan, bounded relative-path results, and distinct conflict UI
- Verified: linked compile, two real embedded lifecycle cycles, session cleanup,
  conflict scanning and result capping, Simulator installation, all prior tests,
  and XCFramework artifact upload
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30695851603

## 2026-08-01 — Bidirectional protocol transfer verification

### Core integration

- Revision: `9964828`
- Host: GitHub-hosted Ubuntu runner
- Result: passed in 1 minute 59 seconds
- Verified: two independent embedded Syncthing processes, isolated identities
  and state, explicit TCP pairing, exact-content transfer in both directions,
  orderly cleanup, race detector, and 77.0% statement coverage
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696198329

### iOS regression

- Revision: `9964828`
- Host: GitHub-hosted macOS runner
- Result: passed
- Verified: XCFramework generation, Xcode project generation, linked app
  compilation, complete native test suite on an iPad Simulator, framework slice
  inspection, and artifact upload
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696198311

## 2026-08-01 — Redacted diagnostics export

### Initial actor-isolation finding

- Revision: `8631477`
- Result: the XCFramework built, but Swift compilation failed
- Finding: a main-actor-isolated no-op recorder was constructed in a default
  argument, which Swift evaluates outside the initializer's actor context
- Run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696657930

### Corrected native build

- Revision: `42def5c`
- Result: passed in 4 minutes 21 seconds
- Change: defer fallback recorder construction to the main-actor-isolated
  initializer body
- Verified: XCFramework generation, generated Xcode project, linked app compile,
  all native tests on an iPad Simulator, framework inspection, and artifact
  upload
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696817304
- Ubuntu core checks: passed in 2 minutes 29 seconds
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30696817294

## 2026-08-01 — Checksum-validated QR pairing

### Windows test cleanup hardening

- Revision: `6e60923`
- Finding: one of five local stress iterations completed the engine assertions
  but Windows still briefly held the disposable vault directory during Go's
  immediate temporary-directory cleanup
- Change: the synchronized-folder test now retries removal for a bounded five
  seconds and still fails if the handle is not released
- Verification: ten consecutive configuration/scan lifecycle iterations passed

### QR feature and initial protocol-test race

- Revision: `da03fde`
- iOS result: passed in 7 minutes 6 seconds
- Verified: QR rendering, scanner UI compilation, camera privacy declaration,
  parser behavior, upstream check-digit validation through the generated bridge,
  all prior Simulator tests, framework inspection, and artifact upload
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697329481
- Core result: failed in the two-process test because the helper requested its
  first scan after configuration commit but before the folder service was ready
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697329485

### Fully green correction

- Revision: `81e3979`
- Change: initial integration scans now use a bounded folder-readiness retry,
  with a focused test proving transient failures are retried
- Ubuntu core result: passed in 2 minutes 25 seconds with race detection and
  77.4% statement coverage
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697607940
- iOS result: passed in 6 minutes 37 seconds
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30697607944

## 2026-08-01 — Completed interface and activity identity correction

- Revision: `69d9475`
- Local host: Windows amd64 with Go 1.25.12
- Local result: `gofmt` clean, `go vet -tags noassets ./...` passed, and
  `go test -tags noassets -count=1 -coverprofile coverage.out ./...` passed at
  79.6% statement coverage
- Local race detector: unavailable because CGO is disabled; retained in the
  Ubuntu workflow
- Ubuntu Core checks: passed with the race detector
- Core run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30710848626
- macOS iOS checks: passed; the XCFramework and Xcode project were generated,
  the linked app compiled, and the native suite ran on an iPad Simulator
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30710848621
- Physical-device build and signing: not run; this remains the next gate

## 2026-08-01 — First-run transparency device build

- Revision: `67afc03`
- Core checks: passed
- iOS application compile and iPad Simulator tests: passed
- Unsigned arm64 physical-device IPA packaging: passed
- iOS run: https://github.com/MVMC4/obsidian-sync-ios/actions/runs/30717953961
- Artifact: `ObsidianSync-unsigned-device-ipa`, retained through 2026-08-08
- Downloaded artifact archive SHA-256:
  `4f74e233c9417c482781669ce497d10505adb7714fb721f69c05d078095a2db1`
- Extracted IPA SHA-256:
  `6835399775576294e6bed6cd8f12efebabc6185dc01dff55f87cb70c7e95ca43`
- Archive integrity and the packaged executable and `Info.plist` were verified
  on Windows
- An earlier build at `c4826d2` exposed one Swift closure compile error; the
  corrected revision above completed the entire workflow

## 2026-08-02 — Windows sideload and physical launch verified

- Installed the GitHub-built unsigned IPA for revision `67afc03` from Windows with
  Sideloadly 0.60.
- Used the Apple web-distributed iTunes/iCloud components required by Sideloadly.
- Completed developer-profile trust, Developer Mode where required, USB installation,
  and first launch on a physical iPad.
- Confirmed that a developer without a locally owned Mac can use the GitHub-hosted
  macOS workflow for compilation and Windows for installation/testing.
- Completed physical desktop-to-iPad, iPad-to-desktop, and delete-propagation checks;
  see `docs/TEST_LOG.md`.
- Captured the active session, Recent activity, and Obsidian vault evidence now stored
  in `docs/images/`.
- The reproducible end-to-end procedure is documented in
  `docs/WINDOWS_TO_IPAD_AND_OBSIDIAN.md`.
