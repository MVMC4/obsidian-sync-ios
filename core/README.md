# Mobile core

This module will expose the smallest possible Go API to Swift through
`gomobile`. Complex Syncthing values remain on the Go side; Swift receives
primitive values and versioned JSON snapshots.

The first scaffold implements and tests lifecycle behavior independently of the
Syncthing adapter. This lets the state contract stabilize before engine startup,
filesystem access, and mobile bindings are introduced.

Run the current checks with:

```sh
go test -tags noassets ./...
go vet -tags noassets ./...
```

The `noassets` tag excludes Syncthing's generated web UI, which this native app
does not start or distribute.

The XCFramework can only be generated and verified on macOS with Xcode.
