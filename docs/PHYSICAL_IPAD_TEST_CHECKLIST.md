# Physical iPad test checklist

Use a disposable vault with a separate backup. Do not use the only copy of a
real notes collection for these tests.

## Record the environment

- Date:
- Commit:
- iPad model:
- iPadOS version:
- Mac and Xcode version:
- Desktop operating system:
- Desktop Syncthing version:
- Network type:

## Prepare the desktop peer

- [ ] Create a disposable Obsidian vault containing several Markdown files and
      one attachment.
- [ ] Add the vault to desktop Syncthing in send-and-receive mode.
- [ ] Record the desktop device ID and exact Syncthing folder ID.
- [ ] Confirm the desktop reports the folder as up to date.
- [ ] Create a backup outside every synchronized directory.

## Build and install

- [ ] Clone the tested commit onto the Mac.
- [ ] Run `./scripts/build-core-xcframework.sh`.
- [ ] Run `./scripts/generate-xcode-project.sh`.
- [ ] Open `app/ObsidianSync.xcodeproj` and select the signing team.
- [ ] Connect the iPad, select it as the run destination, and run the app.
- [ ] Accept the Local Network permission prompt.
- [ ] Confirm the app displays a stable device ID after two launches.

## Vault permission gate

- [ ] In the app, choose `On My iPad / Obsidian / <disposable vault>`.
- [ ] Run the permission diagnostic and confirm create, read, edit, rename, and
      delete all pass.
- [ ] Force-quit the app, relaunch it, and rerun the diagnostic without choosing
      the folder again.
- [ ] Confirm Obsidian observes file changes and no diagnostic directory remains.
- [ ] Revoke folder access if the current iPadOS Settings UI permits it, then
      confirm the app shows a recoverable permission error instead of crashing.
- [ ] Choose the vault again and confirm recovery.

## Pairing and first transfer

- [ ] Add the displayed iPad device ID to desktop Syncthing.
- [ ] Share the desktop vault folder with the iPad device.
- [ ] In the iPad app, enter the desktop device ID and the exact folder ID.
- [ ] Start sync and keep the app visible.
- [ ] Confirm the Local Network prompt, if not already accepted.
- [ ] Confirm the UI progresses through connection, scan, synchronization, and
      verification before reporting completion.
- [ ] Open Obsidian only after the app reports that the engine stopped safely.
- [ ] Verify every seeded note and attachment is present and readable.

## Two-way behavior

- [ ] Create a Markdown note on the desktop, sync, and verify it on the iPad.
- [ ] Edit that note in Obsidian on the iPad, close Obsidian, sync, and verify the
      exact content on the desktop.
- [ ] Rename a note on each side in separate sessions and verify the names.
- [ ] Delete a disposable note on each side and verify propagation.
- [ ] Repeat the sync button twice and confirm the device ID remains unchanged.

## Fault and conflict behavior

- [ ] Start a session with the desktop peer offline and confirm the app says it
      is waiting rather than claiming success.
- [ ] Bring the desktop online and confirm the same session can complete.
- [ ] Start a session, background the app, and confirm the engine stops and vault
      access is released.
- [ ] Disable Local Network access and confirm the app times out or reports the
      peer unavailable without crashing; restore permission afterward.
- [ ] Edit the same note differently on both devices while disconnected, then
      sync and confirm Syncthing preserves a conflict copy.
- [ ] Confirm the app reports the relative conflict path and does not label the
      result as an ordinary clean completion.
- [ ] Interrupt a large attachment transfer, rerun sync, and verify the final
      checksum matches the desktop file.

## Data-integrity cases

- [ ] Unicode and emoji filenames.
- [ ] Deeply nested folders.
- [ ] Zero-byte files.
- [ ] `.obsidian` settings and plugin files.
- [ ] Low-storage failure.
- [ ] iPad restart between sessions.
- [ ] Desktop Syncthing restart between sessions.

## Diagnostics export

- [ ] After a completed session, prepare and share the redacted diagnostics
      report to Files or Mail.
- [ ] Confirm the JSON opens and contains the app/iPadOS versions, terminal
      phase, connection/progress counts, conflict count, and recent phases.
- [ ] Search the exported file for the actual vault name and path, both device
      IDs, peer name, folder ID and label, configured IP address, and displayed
      raw error text; confirm none are present.
- [ ] Confirm no certificate, private key, or Syncthing database content appears
      in the report.

## Exit criteria

The physical gate passes only if:

1. bookmark access survives relaunch;
2. Obsidian observes coordinated changes;
3. a real two-way transfer completes without silent loss;
4. cancellation and permission loss always release resources cleanly;
5. conflict copies are visible and explained; and
6. the backup can restore the disposable vault.

Record failures in `BUILD_LOG.md` or `TEST_LOG.md` with the commit, environment,
exact reproduction steps, and whether any file content was lost.
