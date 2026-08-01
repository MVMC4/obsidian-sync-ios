# Project status

## Active phase

Phase 0 — feasibility gates.

## Next concrete task

Build a tiny SwiftUI device spike that:

1. lets the user select `On My iPad/Obsidian/<vault>`;
2. persists and resolves the returned bookmark;
3. creates, reads, edits, renames, and deletes a nested test file;
4. repeats those operations after terminating and relaunching the app; and
5. verifies that Obsidian sees the changes.

## Exit condition

Do not start the full UI until the vault-access and embedded-engine gates in
Phase 0 of `docs/PROJECT_PLAN.md` both pass on a physical iPad.

## Known constraints

- The final iOS build requires macOS, Xcode, signing, and a physical iPad.
- Foreground manual sync is the reliable baseline.
- Bookmark access can be revoked or become stale.
- Syncthing metadata and identity must live in this app's own container, never
  inside the Obsidian vault.

