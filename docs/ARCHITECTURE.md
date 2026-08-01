# Architecture

## System shape

```text
Existing Windows/Linux Syncthing nodes
                  |
      Syncthing encrypted protocol
                  |
       Go engine inside iOS process
                  |
       narrow primitive/JSON bridge
                  |
 Swift session controller and SwiftUI
                  |
 security-scoped directory permission
                  |
       On My iPad / Obsidian / Vault
```

## Components

### SwiftUI presentation

Displays onboarding, pairing, session progress, actionable errors, conflicts,
and diagnostics. It observes application state but does not directly manipulate
engine files or bookmarks.

### SyncSessionController (Swift)

Owns the foreground session state machine. It acquires vault access, starts the
Go engine, configures the selected folder, requests a scan, evaluates completion,
stops the engine, and releases access. All UI-facing state changes occur on the
main actor.

### VaultAccessCoordinator (Swift)

Owns folder picking, bookmark persistence/resolution, stale and revoked access,
and balanced security-scope lifetimes. It exposes a temporary resolved path only
for an active session.

### SyncthingBridge (generated Objective-C bindings)

Contains only gomobile-compatible APIs. The contract uses strings, bytes,
numbers, booleans, small interfaces, or JSON. Generated code is a build artifact,
not hand-edited source.

### MobileCore (Go)

Wraps upstream `lib/syncthing`. It owns engine lifecycle, device identity,
configuration, database, events, and status projection. It must not assume a
shell, subprocess, web browser, or unrestricted filesystem.

## Storage boundaries

### App-owned Application Support

- device certificate and private key;
- Syncthing configuration;
- index database;
- bookmark record;
- logs and migration markers.

These files are private app state and are excluded from the vault.

### User-selected Obsidian vault

- Markdown notes;
- attachments;
- `.obsidian` settings and plugins;
- `.stignore`, `.stfolder`, conflict copies, and optional versioning artifacts.

No device identity, index database, or private key may be written here.

## Security model

- Syncthing provides mutually authenticated, encrypted peer transport.
- iOS grants the app filesystem access only after explicit folder selection.
- The app releases security-scoped access after every session.
- Private keys remain in the app container with data protection enabled; Keychain
  storage can be evaluated for identity key material during implementation.
- Logs are redacted before export.
- No analytics, hosted coordinator, or custom cloud backend is required for MVP.

## Lifecycle model

The Go engine is an in-process service with explicit start/stop boundaries. App
backgrounding is treated as an interruption. The controller stops accepting new
work, requests an orderly engine stop, releases the bookmark scope, persists the
last safe status, and becomes resumable on the next foreground launch.

The MVP uses Syncthing's TCP transport with discovery and relay support. QUIC,
STUN, and NAT traversal remain disabled until their shutdown is race-free in the
embedded lifecycle. Configuration and event services are explicitly joined
before the app releases engine state or vault access.

## Session completion contract

Swift polls a versioned JSON snapshot instead of importing Syncthing model
types. A session is complete only after consecutive snapshots report all of the
following:

- the configured peer is connected;
- the local folder state is idle;
- local needed items and deletes are zero;
- remote needed items and deletes are zero; and
- local and remote completion are both 100 percent.

After verification, Swift stops the engine before releasing the security-scoped
vault URL. Timeout, cancellation, configuration failure, and app foreground loss
all enter the same cleanup path.

## Why not the original low-level package plan?

Current Syncthing provides `lib/syncthing.App` with lifecycle methods and an
`Internals` boundary intended for importing applications; its documentation even
mentions an iOS app as an upstream consumer. Building directly from scanner,
model, database, discovery, and configuration packages would couple this project
to more volatile internals and duplicate upstream initialization logic.

## Reference implementation policy

Sushitrain is useful evidence and a source of implementation patterns: it uses a
Swift/SwiftUI front end, a Go framework, `gomobile`, and a full in-process
Syncthing node. We should study and credit compatible MPL-2.0 code where useful,
but keep this MVP narrow and avoid copying its branding or reserved artwork.
