# Decisions and risks

## Accepted decisions

### D-001: foreground-first operation

The MVP performs explicit user-initiated sessions while the app is visible.
iOS has no general-purpose mechanism for a continuously running network daemon,
and opportunistic background APIs do not guarantee a schedule.

### D-002: embed upstream Syncthing

Use `github.com/syncthing/syncthing/lib/syncthing` through a thin Go wrapper.
Do not reimplement the protocol and do not bind upstream complex types directly
to Swift.

### D-003: prove folder access before product work

A security-scoped directory URL can grant recursive access, but bookmarks can be
stale or revoked and Apple calls for coordinated file access. Direct sustained Go
filesystem access to an Obsidian-owned folder must be proven on a physical iPad.

### D-004: separate engine state from synced data

Syncthing identity, configuration, database, and logs stay in Application
Support. Only the mapped folder content lives in the selected vault.

### D-005: start with one disposable vault

The first end-to-end target is a throwaway vault with backups, not the user's
primary notes.

### D-006: TCP-first transport for the MVP

Listen over Syncthing TCP with local/global discovery and relays available, but
do not start QUIC, STUN, or NAT traversal. A race-enabled integration run found
an upstream QUIC/STUN shutdown race. Foreground sessions need predictable teardown
more than an additional transport. Reconsider QUIC after upstream behavior is
safe and repeatable on iPadOS.

## Open decisions

- Minimum iOS/iPadOS version.
- SwiftUI observation approach and concurrency boundary for Go callbacks.
- Bookmark persistence format after the Phase 0 spike.
- Whether sustained Go I/O needs a Swift coordination adapter or can safely use
  the locally selected Obsidian directory during the held security scope.
- Pairing UX: manual device ID first, QR scanning in the MVP or later.
- Whether the final UI should expose discovery and relay controls or keep the
  TCP-first defaults implicit.
- Whether `.obsidian/workspace*.json` and other high-churn UI state should be in
  a recommended default `.stignore` template.
- Personal sideload only versus TestFlight/App Store release.

## Risk register

| Risk | Impact | First mitigation |
|---|---|---|
| Obsidian vault cannot be persistently selected or written | Architecture blocker | Phase 0 device spike; choose a storage pivot if it fails |
| Uncoordinated Go writes conflict with the file provider or Obsidian | Data corruption or stale views | Physical stress test; design a coordination adapter or session exclusivity |
| App suspension interrupts the engine | Partial session and confusing state | Foreground state machine, orderly stop, recovery on next launch |
| gomobile cannot bind needed APIs | Build blocker | Primitive/JSON facade; follow current Sushitrain patterns |
| Upstream internal API changes | Maintenance burden | Pin versions and isolate all use behind `MobileCore` |
| Concurrent note edits create conflict files | User confusion | Visible conflicts, backups, documented resolution flow |
| `.obsidian` churn produces noisy conflicts | Poor Obsidian UX | Test and propose conservative ignore defaults, never silently impose them |
| Device identity or logs leak | Security/privacy loss | App-private protected storage and redacted diagnostic export |
| Free provisioning expires | App stops launching | Treat free signing as development-only; document distribution choice |

## Fallbacks if direct vault access fails

Evaluate in this order:

1. An app-owned Documents vault that Obsidian can open as a vault on the target
   iPadOS/Obsidian versions.
2. A user-selected shared iCloud Drive or third-party File Provider directory.
3. Explicit import/export or Shortcut-assisted copying with clear ownership.
4. A File Provider extension, recognizing that this is a significantly larger
   architecture and still does not create unrestricted background execution.

Do not silently copy between two independent vaults; that creates a second sync
algorithm and increases conflict and data-loss risk.

## Primary references checked during planning

- Apple, Providing access to directories:
  https://developer.apple.com/documentation/uikit/providing-access-to-directories
- Apple DTS, iOS Background Execution Limits:
  https://developer.apple.com/forums/thread/685525
- Syncthing application package:
  https://pkg.go.dev/github.com/syncthing/syncthing/lib/syncthing
- Syncthing source and MPL-2.0 license:
  https://github.com/syncthing/syncthing
- Sushitrain reference implementation and build notes:
  https://github.com/pixelspark/sushitrain
