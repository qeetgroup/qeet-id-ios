# Boundaries — qeet-id-ios

**Level:** L2 · **Last verified:** 2026-11-06
**Verification scope:** ownership from `qeet-id-context/REPOSITORIES.md`; endpoints read from `qeet-id-server`.

## Owns

The iPhone authenticator: TOTP generation and storage, the on-device Keychain vault, linking with a pairing code,
answering sign-in requests, the app lock and privacy cover, AutoFill of codes, and the app's screens.

## Does not own

| Not owned | Owner |
|---|---|
| Challenge validity, number matching, MFA policy, session issuance | `qeet-id-server` |
| Device-credential issuance, expiry (180 days) and revocation | `qeet-id-server` |
| The `/v1/mfa/push/*` contract and the APNs payload | `qeet-id-server` |
| Pairing codes (issued in the console) | `qeet-id-console`, `qeet-id-server` |
| The design system | `qeetrix-ios` (never patched here) |
| The Android app | `qeet-id-android` |

## Consumes

`api.id.qeet.in` (the five calls in [context.md](context.md#api)), APNs, Qeetrix for iOS, and Apple frameworks:
SwiftUI, CryptoKit, Security, LocalAuthentication, AVFoundation, UserNotifications, AuthenticationServices, Network.
**Nothing else.**

## Provides

Codes and approvals to a person, and codes to iOS AutoFill. No API, no package, nothing another repository consumes.

## Security boundaries

| Boundary | Enforcement |
|---|---|
| App → Keychain | `…ThisDeviceOnly`, not synchronizable, shared access group with the AutoFill extension only |
| Secret → memory | Read by `CodeBook` to compute codes; never SwiftUI state, a log or a toast |
| Opening the app | Face ID or passcode when the lock is on; privacy cover in the app switcher always |
| Approving | Typed number + fresh `.deviceOwnerAuthentication`, whatever the lock setting |
| Phone → server | Device credential in the JSON body; no bearer on `respond`, by design |
| AutoFill | Device-owner check before showing or filling a code |

## Requires cross-repository coordination

| Change | Reaches |
|---|---|
| Push endpoint shape, the payload, error codes | `qeet-id-server` |
| Device-credential semantics | `qeet-id-server` |
| The pairing QR's link format (`qeetidauth://pair?code=…`) | `qeet-id-console` |
| A missing Qeetrix component or a Qeetrix bug | `qeetrix-ios` |

## Hard limits

1. Never put a secret in SwiftUI state, a log, a toast or a crash report.
2. Never store a secret outside the Keychain, or with an accessibility that is not `…ThisDeviceOnly`.
3. Never approve without the typed number and a fresh device-owner check.
4. Never add a bearer to `respond`, and never ask for an access token.
5. Never default to localhost or a non-production address; never accept an override in Release.
6. Never link without the person's tap.
7. Never change another repository from a task scoped to this one.
