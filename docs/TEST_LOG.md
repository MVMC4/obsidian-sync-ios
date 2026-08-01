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
