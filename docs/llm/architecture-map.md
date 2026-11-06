# Architecture Map — qeet-id-ios

**Level:** L2 · **Last verified:** 2026-11-06
**Verification scope:** every path confirmed to exist; screen numbers are the approved mockup's.

## Project

| Need | Path |
|---|---|
| Repository identity | [`qeet-repo.yml`](../../qeet-repo.yml) |
| Agent instructions | [`AGENTS.md`](../../AGENTS.md) |
| Build settings (all targets) | `Configs/Project.xcconfig`, `Configs/{App,AutoFill,NotificationService,Tests,UITests}.xcconfig` |
| Signing placeholder (team in an ignored `.local` file) | `Configs/Signing.xcconfig` |
| Info.plists (Debug-only ATS via `INFOPLIST_PREPROCESS`) | `Configs/*-Info.plist` |
| Entitlements | `Configs/QeetID.entitlements`, `Configs/AutoFill.entitlements`, `Configs/NotificationService.entitlements` |
| The project, scheme, resolved packages | `QeetID.xcodeproj` |
| App icon (any, dark, tinted), Q-key mark, colours | `QeetID/Resources/Assets.xcassets` |
| String Catalogs | `QeetID/Resources/Localizable.xcstrings`, `AutoFill/`, `NotificationService/` (`Scripts/sync-strings.sh`) |
| Privacy manifest | `QeetID/Resources/PrivacyInfo.xcprivacy` |
| Lint, CI simulator picker | `Scripts/lint.sh`, `Scripts/ci-simulator.sh`; `.swift-format` |
| CI | `.github/workflows/ci.yml`, `.github/workflows/security.yml` |

## Screens

| Screen (mockup) | Path |
|---|---|
| 1 Welcome · 2 Lock Qeet ID · 3 Get sign-in requests | `QeetID/Onboarding/` |
| 4 Accounts · 5 No accounts yet · 9 Context menu · 10 Delete · 26 Rename · 24 Problems | `QeetID/Accounts/AccountsView.swift`, `AccountRow.swift` |
| 6 Scan a QR code · 7 Camera access is off | `QeetID/AddAccount/AddAccountView.swift`, `QeetID/Scanning/` |
| 8 Type the setup key | `QeetID/AddAccount/SetupKeySheet.swift` |
| 11 Link this iPhone · 12 Scan the pairing code | `QeetID/Link/LinkIntroView.swift` |
| 13 Name this iPhone | `QeetID/Link/NameAndLinkView.swift` |
| 14 iPhone linked | `QeetID/Link/LinkedView.swift` |
| 15 A request arrives (notification) | `NotificationService/NotificationService.swift` |
| 16 Review and type the number · 17 Face ID · 18–20 Outcomes | `QeetID/Approvals/` |
| 21 Locked (and the privacy cover) | `QeetID/Lock/LockedView.swift`, `ShieldWindow.swift` |
| 22 Settings · 23 Unlink | `QeetID/Settings/SettingsView.swift` |
| 25 AutoFill codes | `QeetID/AutoFillSetup/AutoFillSetupView.swift` |
| 27 AutoFill: choose a code | `AutoFill/CodePickerView.swift`, `CodePickerModel.swift`, `CredentialProviderViewController.swift` |

## App structure

| Concern | Path |
|---|---|
| Entry, APNs callbacks, notification delegate | `QeetID/App/QeetIDApp.swift`, `AppDelegate.swift`, `QeetID/Notifications/NotificationRouter.swift` |
| App state: shield, routes, modals, pending check, deep links | `QeetID/App/AppModel.swift`, `RootView.swift` |
| Accounts and the code clock | `QeetID/Accounts/AccountsModel.swift` |
| Copy a code (local-only, 60 s) from the menu | `QeetID/Accounts/SensitiveCopy.swift` |
| The device link: link, unlink, pending, respond, new push token | `QeetID/Link/LinkModel.swift` |
| APNs token | `QeetID/Notifications/PushRegistrar.swift` |
| A sign-in request, number, Face ID, outcomes | `QeetID/Approvals/SignInRequestModel.swift` |
| App lock | `QeetID/Lock/AppLock.swift` |
| Preferences (no secrets) | `QeetID/Support/Preferences.swift` |
| Offline state | `QeetID/Support/NetworkMonitor.swift` |
| UI-test launch arguments (Debug only) | `QeetID/Support/UITestSupport.swift` |
| App-level pieces Qeetrix lacks | `QeetID/Components/` (`ActionFooter`, `FeatureRow`/`StepNumber`, `QeetIDMark`) |

## Core (app + both extensions)

| Concern | Path |
|---|---|
| Keychain (this-device-only, shared group) | `Core/Keychain/Keychain.swift` |
| Accounts and their store | `Core/Accounts/` |
| RFC 6238, Base32, otpauth, setup keys, the code book | `Core/Codes/` |
| Device link and pairing codes | `Core/Link/` |
| API client, errors, models, server dates | `Core/API/` |
| Push payload, user agent in words | `Core/Approvals/` |
| AutoFill site matching | `Core/AutoFill/ServiceMatcher.swift` |
| Identifiers, API address (no localhost default), logging | `Core/AppIdentity.swift`, `Core/Support/` |

## Shared (app + AutoFill)

| Concern | Path |
|---|---|
| Face ID / Touch ID / passcode | `Shared/Security/DeviceOwnerAuthentication.swift` |
| One-time-code identities for AutoFill | `Shared/AutoFill/OneTimeCodeIdentities.swift` |
| Issuer tile, account title, list-row styling | `Shared/Design/` |

## Tests

| Kind | Path |
|---|---|
| Unit (Swift Testing, hosted in the app) | `QeetIDTests/` — RFC vectors, parsing, Keychain, API with `StubURLProtocol`, view models |
| UI (XCTest) | `QeetIDUITests/` — every flow; `StubServer` stands in for the API on localhost |
| Live server end to end (skipped unless `TEST_RUNNER_QEETID_E2E_URL` is set) | `QeetIDUITests/LiveServerE2ETests.swift` |

## Keychain items

```text
service com.qeetgroup.qeetid.account       one item per account: value = secret, kSecAttrGeneric = metadata JSON
service com.qeetgroup.qeetid.device-link   one item: user id, device id, device credential, name, email, APNs token
```

## Endpoints

```text
POST /v1/mfa/push/pairing/claim                 the pairing code; no bearer
GET  /v1/mfa/push/challenges/{id}               public
POST /v1/mfa/push/devices/{id}/pending          device credential in the body
POST /v1/mfa/push/challenges/{id}/respond       device credential + number in the body
POST /v1/mfa/push/devices/{id}/push-token       device credential in the body; 404 tolerated
POST /v1/mfa/push/devices/{id}/unlink           device credential in the body
```
