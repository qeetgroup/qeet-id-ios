# Repository Context — qeet-id-ios

**Level:** L2 · **Status:** development · **Last verified:** 2026-11-06
**Verification scope:** targets, build settings and entitlements read from `Configs/` and `QeetID.xcodeproj`.

## Identity

**Qeet ID for iPhone**, the native authenticator. SwiftUI, Swift 6 language mode (complete strict concurrency,
warnings as errors), iOS 17 or later, iPhone only, built with Xcode 27. It replaces the Expo / React Native app in
`qeet-id-auth`; `qeet-id-android` is its Android sibling with the same flows and screen numbering.

## Context inheritance

```text
qeet-context (L0)  →  qeet-id-files (L1)  →  qeet-id-server (contract + enforcement)
                                            →  qeet-id-ios (L2, this document)
```

## Responsibilities

1. **Sign-in codes.** RFC 6238 TOTP, computed on the iPhone, for any site; added by QR code or setup key.
2. **Sign-in approvals.** Linking the iPhone to a Qeet ID account with a pairing code, then approving or denying each
   sign-in with number matching and a fresh device-owner check.
3. **Protection.** The Face ID app lock, the privacy cover in the app switcher, this-device-only Keychain storage.
4. **AutoFill.** One-time codes above the keyboard on iOS 18 and later, through an AutoFill credential provider.

## Non-responsibilities

It verifies nothing and decides nothing about a sign-in: whether a request is open, whether the number matches and what
the sign-in gets belong to `qeet-id-server`. It never holds a Qeet ID session or an access token.

## Design system

Every screen uses **Qeetrix for iOS** (`qeetgroup/qeetrix-ios`, Swift Package Manager, `from: "0.3.0"`). Qeetrix wraps
the system's own controls and presentations — navigation bars and large titles, search, sheets, alerts, action sheets,
context menus — and carries Qeetrix's square geometry, filled fields, label-first buttons, ruled surfaces, sharp icons
and Ember. Where the approved mockup needs something Qeetrix lacks, the app builds the smallest piece from Qeetrix
tokens, and the gap is recorded for Qeetrix.

## API

```text
https://api.id.qeet.in   every build; a Debug build alone accepts -api-url <url> at launch
```

| Call | Endpoint | Credential |
|---|---|---|
| Link | `POST /v1/mfa/push/pairing/claim` `{code, name, push_token, platform: "ios"}` | the pairing code |
| Read a request | `GET /v1/mfa/push/challenges/{id}` | none (it never reveals the number) |
| Answer it | `POST /v1/mfa/push/challenges/{id}/respond` `{user_id, device_token, approved, number}` | device credential |
| New APNs token | `POST /v1/mfa/push/devices/{id}/push-token` `{user_id, device_token, push_token}` → 204 | device credential |
| Unlink | `POST /v1/mfa/push/devices/{id}/unlink` `{user_id, device_token}` → 204 | device credential |

`push_token` is the APNs device token as lowercase hex. The claim's response may carry `account.email`; the app shows
it when present and says "your Qeet ID account" otherwise. A 404 from the push-token route (a server without it) is
tolerated.

## Push

The server sends an APNs alert, `interruption-level` time-sensitive, `mutable-content` 1, `thread-id` `sign-in`, with
`type: sign_in_request`, `challenge_id` and `action` beside `aps`. The notification service extension reads the
request and adds the browser and system ("from Chrome on macOS") to the body; on any failure the server's text stands.
Tapping the notification opens the request after the app lock.

## How the pieces work

- **Codes.** `AccountsModel` lists accounts from the Keychain without reading any secret; `CodeBook` reads each secret
  once into a CryptoKit key in memory and makes codes; a clock task wakes when the earliest code ends. While the app is
  locked or in the background the model is suspended: no secret is read and no code is kept.
- **The shield.** `AppModel.shield` is the Locked screen while locked, and a privacy cover whenever the scene isn't
  active (except during the app's own Face ID and permission prompts). It is drawn in a window above the app's
  (`ShieldWindowController`), so it covers sheets, alerts and full-screen covers, and the app switcher never shows a
  code. Returning from the background locks (when the lock is on) and asks for Face ID by itself.
- **Requests.** A notification tap or a foreground arrival opens the request (queued behind the lock). Without push, the
  app asks the server for waiting requests on returning to the foreground and on pull to refresh, and opens the newest.
  The request's countdown uses the server's clock (the `Date` header), so a phone with a wrong clock still counts right.
- **Linking.** The APNs token (hex) goes with the claim. Debug simulator builds, which get no token without a team's
  push key, stand in a fixed one, so linking works against a local server. Linking to a different account unlinks the
  old one. A new APNs token is sent to the server; a server without that route is tolerated.
- **AutoFill.** The extension lists the requesting site's accounts first (remembered sites, then issuer names that match
  a label of the host), asks for Face ID before any code shows, and fills on a tap. Accounts for other sites open first,
  a deliberate second step. An account is tied to a site, and registered with `ASCredentialIdentityStore` for the
  QuickType bar, only after the person chose it there.

## Decisions

| Decision | Why |
|---|---|
| Folder-synchronised groups, settings in xcconfig files | A small, reviewable project file; the folders are the truth |
| One project, shared folders (`Core/`, `Shared/`) instead of a local package | The extensions compile what they need without public-API boilerplate; tests reach everything with `@testable import QeetID` |
| Keychain metadata in `kSecAttrGeneric`, secret in the value | Listing and renaming never read a secret |
| `WhenUnlockedThisDeviceOnly` for codes, `AfterFirstUnlockThisDeviceOnly` for the link | Codes are only needed unlocked; a token refresh may run in the background |
| Approve needs the number and a fresh device-owner check; deny needs neither | Number matching stops push-fatigue approvals; denying can't hurt the person |
| The lock switch needs a device-owner check both ways | Someone with the unlocked phone can't simply turn it off |
| Lock and privacy cover in their own window | SwiftUI overlays can't cover sheets, alerts and full-screen covers |
| A Debug-only `-api-url`, kept in the App Group | Lets a developer and the notification extension use a local server; Release has no override and no ATS exception |
| Nearest Qeetrix catalogue icons where the mockup's are missing | Qeetrix components accept only catalogue icons; the gaps are recorded for Qeetrix |
