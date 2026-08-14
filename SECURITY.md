# Security policy

## Supported version

Security fixes are applied to the latest tagged MVP release and `main`.

## Reporting a vulnerability

Please use GitHub's private vulnerability-reporting feature for this repository. Do not place credentials, private schedules, cookies, or reproduction data containing personal information in a public issue.

Include the affected version, macOS version, a minimal reproduction, expected behavior, and observed behavior. Remove all secrets and personal content first.

## Security boundaries

- TopBuddy is not a credential manager.
- Only HTTPS, loopback HTTP, and validated app bundle identifiers are opened from schedules.
- Codex runs only after a user message, ephemerally and read-only.
- Apple Music uses a fixed command set; raw AppleScript is not accepted.
- App termination is graceful and confirmation-gated.
- Release artifacts must report their signing and notarization state accurately.
