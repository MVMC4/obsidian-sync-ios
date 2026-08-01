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
