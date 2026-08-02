# Contributing to Vault Sync

Thanks for helping improve Vault Sync. Contributions are welcome through
issues, documentation changes, focused pull requests, testing reports, and code
review.

By submitting a contribution, you agree that your original contribution may be
distributed under this repository's [MIT License](LICENSE). Third-party code
and assets must retain their own compatible notices and licenses.

## Before opening an issue

1. Search existing issues and pull requests.
2. Read the
   [complete Windows/iPad setup guide](docs/WINDOWS_TO_IPAD_AND_OBSIDIAN.md)
   and project [status](STATUS.md).
3. Reproduce the problem with a disposable vault and an independent backup.
4. Remove credentials, full device IDs, private addresses, vault content,
   certificates, provisioning profiles, and Apple authentication data.

Use GitHub Issues for reproducible bugs and scoped feature proposals. Use the
security process in [SECURITY.md](SECURITY.md) for vulnerabilities or anything
that would put users' data or credentials at risk.

## Development setup

The repository has two independently tested parts:

- `core/`: Go facade around the embedded Syncthing engine.
- `app/`: native SwiftUI application linked to the generated XCFramework.

Run the core checks from `core/`:

```sh
gofmt -w .
go vet -tags noassets ./...
go test -tags noassets -race ./...
```

Build the iOS framework and generated Xcode project on macOS:

```sh
brew install xcodegen
./scripts/build-core-xcframework.sh
./scripts/generate-xcode-project.sh
```

The generated Xcode project and XCFramework are intentionally not committed.
See [Building and installing](docs/BUILDING.md) for the complete toolchain.

Contributors without a Mac can still work on Go code, documentation, fixtures,
and reviewable Swift changes. The `iOS checks` GitHub workflow performs the
macOS framework build, Swift compile, iPad Simulator tests, and unsigned device
IPA packaging.

## Making a change

1. Fork the repository.
2. Create a focused branch from the latest `main`.
3. Keep the change small and avoid unrelated formatting or generated files.
4. Add or update tests for changed behavior.
5. Update architecture, build, test, or user documentation when behavior or
   workflow changes.
6. Run every applicable local check.
7. Push the branch and open a pull request against `main`.

Do not commit:

- Apple Account credentials or verification codes;
- Syncthing certificates, keys, configuration, indexes, or complete device IDs;
- `.mobileprovision`, `.p12`, signing identities, or personal Xcode settings;
- real vault contents, private paths, addresses, or unredacted diagnostics;
- generated `.xcodeproj`, XCFramework, IPA, DerivedData, or coverage output.

## Pull-request expectations

A pull request should:

- explain the problem and the chosen solution;
- state which checks were run and where;
- identify untested physical-device behavior honestly;
- include screenshots for visible UI changes;
- preserve foreground cleanup and security-scoped resource release;
- preserve diagnostic redaction and app-private Syncthing identity storage;
- avoid claiming Simulator coverage proves physical Files, camera, signing, or
  local-network behavior; and
- pass both required GitHub Actions workflows.

Maintainers may ask for a smaller change, additional tests, safer migration
behavior, or clearer documentation before merging.

## Documentation contributions

Documentation-only pull requests are welcome. Keep headings and links relative
where practical, wrap prose consistently with neighboring files, provide alt
text for images, and do not publish screenshots containing credentials or
private vault data.

## Physical-device reports

Use a disposable vault and record:

- tested commit and Actions run;
- iPad model and iPadOS version;
- desktop OS and Syncthing version;
- installation route and Sideloadly version, when applicable;
- network topology;
- exact reproduction steps and visible phase;
- whether content, rename, deletion, conflict, and restart cases passed; and
- whether an independent backup restored successfully.

The full gate is in
[PHYSICAL_IPAD_TEST_CHECKLIST.md](docs/PHYSICAL_IPAD_TEST_CHECKLIST.md).

## Community standards

Participating in this repository means following the
[Code of Conduct](CODE_OF_CONDUCT.md). Be patient with people learning iOS,
Syncthing, Git, or sideloading; explain risks without shaming users; and put
data safety ahead of convenience.
