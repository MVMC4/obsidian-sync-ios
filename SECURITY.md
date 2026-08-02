# Security policy

## Supported version

Security fixes target the latest commit on the default `main` branch. This is a
development project without stable release branches or long-term support
guarantees yet.

## Reporting a vulnerability

Do not publish an exploit, credential, certificate, complete device ID, private
address, vault content, or unredacted diagnostic report in a public issue.

Use GitHub's private vulnerability reporting option on the repository Security
page when it is available. Otherwise, contact the repository owner through the
contact method listed on the
[maintainer's GitHub profile](https://github.com/MVMC4). If no private channel
is listed, open a minimal issue asking the maintainer to establish private
contact; do not include the vulnerability details in that issue.

Include:

- affected commit and platform versions;
- impact and realistic attack conditions;
- minimal reproduction steps using disposable data;
- whether credentials, signing material, device identity, or vault contents
  may have been exposed; and
- any proposed mitigation.

Maintainers will acknowledge a usable report, investigate it, and coordinate a
fix and disclosure as capacity allows. Please allow a reasonable remediation
window before public disclosure.

## Security boundaries

- Vault Sync uses the embedded Syncthing protocol and does not operate a hosted
  vault service.
- Syncthing identity and state belong in the app-private container.
- Folder access is granted through iPadOS security-scoped bookmarks.
- Redacted diagnostics must not contain vault paths or names, device IDs,
  addresses, folder IDs, peer labels, keys, certificates, or raw errors.
- Sideloadly, Apple authentication, provisioning, and the user's desktop
  Syncthing installation are external trust boundaries.

Suspected data-loss behavior should also be treated as a security-sensitive
report until its scope is understood.
