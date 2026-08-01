# Install on an iPad from Windows

This route uses GitHub Actions to compile the app on a hosted Mac, then uses
Sideloadly on Windows to apply a personal development signature and install the
IPA. It does not require a local Mac or a jailbroken iPad.

Sideloadly is a third-party tool and is not part of this repository or Apple.
Only download it from `https://sideloadly.io/`. Never put an Apple Account
password, app-specific password, verification code, certificate, or signing
profile in the repository.

## 1. Produce the IPA

Every successful `iOS checks` workflow run packages the physical-device app as
an artifact after the linked app builds and all iPad Simulator tests pass. A
manual run can also be started from **GitHub > Actions > iOS checks > Run
workflow**.

1. Open the successful workflow run.
2. Find **Artifacts** on the run summary.
3. Download `ObsidianSync-unsigned-device-ipa`.
4. Extract the downloaded ZIP. It contains:
   - `ObsidianSync-unsigned.ipa`
   - `ObsidianSync-unsigned.ipa.sha256`
5. Optionally verify the download in PowerShell:

   ```powershell
   Get-FileHash .\ObsidianSync-unsigned.ipa -Algorithm SHA256
   Get-Content .\ObsidianSync-unsigned.ipa.sha256
   ```

The two hexadecimal hashes must match. The GitHub artifact expires after seven
days; rerun the workflow whenever a fresh build is needed.

## 2. Prepare Windows and the iPad

1. Install Sideloadly from its official site or the `iOSGods.Sideloadly`
   Windows Package Manager package.
2. Install the Apple device components requested by Sideloadly. If it requests
   iTunes or iCloud, use the direct Apple downloads linked by Sideloadly rather
   than the Microsoft Store editions.
3. Restart Windows if an Apple component requests it.
4. Connect the unlocked iPad by USB.
5. Tap **Trust** on the iPad and enter its passcode.
6. If iPadOS requests Developer Mode, enable it under **Settings > Privacy &
   Security > Developer Mode**, restart the iPad, and confirm after restart.

## 3. Sign and install

1. Open Sideloadly and confirm the connected iPad appears as the target device.
2. Drag `ObsidianSync-unsigned.ipa` into Sideloadly.
3. Enter the Apple Account used for personal development signing. Completing
   Apple's authentication happens at install time, not in GitHub Actions.
4. Keep the default Apple ID sideload mode and start the installation.
5. Approve any two-factor authentication prompt from Apple.
6. Wait until Sideloadly reports a successful installation, then launch
   **ObsidianSync** on the iPad.

If iPadOS blocks the developer app, open **Settings > General > VPN & Device
Management**, select the development identity, and trust it. The exact wording
depends on the installed iPadOS version.

## 4. Keep the free signature active

A free Personal Team signature expires after seven days. Enable Sideloadly's
automatic refresh and keep the Windows computer and iPad reachable over USB or
the same local network. Use the same Apple Account and bundle identifier for
refreshes so the new installation replaces the old one without intentionally
clearing app data.

If automatic refresh does not run before expiry, repeat the sign-and-install
steps with the current IPA. Do not delete the existing app first unless its
local settings have been backed up.

## 5. Run the physical-device gate

Use `docs/PHYSICAL_IPAD_TEST_CHECKLIST.md` with a disposable, backed-up Obsidian
vault. Simulator success does not prove Files-provider access, camera capture,
Local Network permission, or real Syncthing traffic on an iPad.

## Troubleshooting

- **No iPad in Sideloadly:** unlock it, reconnect USB, accept **Trust**, and
  verify Apple Mobile Device Support is installed and running.
- **Provisioning or App ID error:** wait for an expired Personal Team App ID to
  clear, remove another sideloaded app, or use a different unique bundle ID.
- **Integrity cannot be verified:** reconnect to the internet, reinstall using
  the same Apple Account, and confirm Developer Mode and developer trust.
- **App immediately stops opening after several days:** the free signature
  expired; sign and install it again.
- **Installation succeeds but sync does not:** accept Local Network access and
  follow the physical-iPad checklist; installation and Syncthing pairing are
  separate stages.
