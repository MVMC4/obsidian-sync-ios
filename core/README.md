# Mobile core

This module will expose the smallest possible Go API to Swift through
`gomobile`. Complex Syncthing values remain on the Go side; Swift receives
primitive values and versioned JSON snapshots.

The current implementation embeds the released Syncthing engine, persists its
device identity, exposes one-shot lifecycle operations, configures peers and a
send-receive vault folder, and requests explicit foreground scans.

The bound API intentionally accepts primitive strings and JSON. Syncthing's Go
configuration and model types do not cross the mobile bridge.

Run the current checks with:

```sh
go test -tags noassets ./...
go vet -tags noassets ./...
```

The `noassets` tag excludes Syncthing's generated web UI, which this native app
does not start or distribute.

The XCFramework can only be generated and verified on macOS with Xcode.
