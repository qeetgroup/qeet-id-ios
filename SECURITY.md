# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities privately; do not open a public GitHub issue. Email **security@qeet.in**
with:

- a description of the vulnerability and its impact;
- steps to reproduce, with the iPhone model and iOS version;
- the app version (Settings › Help and privacy in the app).

We aim to acknowledge reports within 2 business days.

## What this app holds

Qeet ID for iPhone holds real secrets on a device Qeet Group does not control:

| Secret | Where | Protection |
|---|---|---|
| Each account's TOTP secret | Keychain, one item per account | `WhenUnlockedThisDeviceOnly`, never synchronizable, shared only with the app's own AutoFill extension |
| The device credential that approves sign-ins | Keychain, one item | `AfterFirstUnlockThisDeviceOnly`, never synchronizable; sent only in request bodies; removed from the server on unlink |
| Codes on the clipboard | The pasteboard | Local to this iPhone (never Universal Clipboard) and removed after 60 seconds |

`…ThisDeviceOnly` items never leave the iPhone: not to iCloud Keychain, not to an iCloud or computer backup, and not to
a new iPhone. Restoring a backup brings back no secret.

## Controls

- **App lock:** Face ID, Touch ID or the passcode (`.deviceOwnerAuthentication`) when the app opens or returns, and a
  privacy cover in the app switcher.
- **Approvals:** the 2-digit number from the sign-in screen, then a fresh device-owner check, before any approval is
  sent; the server refuses a wrong number.
- **AutoFill:** a device-owner check before any code is shown or filled; codes for other sites are a deliberate extra
  step.
- **Linking:** only with a one-time pairing code, and only on the person's tap.
- **Network:** HTTPS to `api.id.qeet.in` only; Release builds have no way to use another address and no App Transport
  Security exception.
- **Logs:** no secret, code, pairing code or push token is ever logged.

## Scope

This policy covers the `qeet-id-ios` app and its extensions. The decisions the app relies on (whether a request is
open, whether the number matches, what a sign-in gets) belong to Qeet ID's server; report those at the same address.

## Supported versions

Only the latest version on the App Store receives security fixes.

## Disclosure

We credit reporters, unless they ask otherwise, in the release notes once a fix ships.
