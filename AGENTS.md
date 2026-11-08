# AGENTS.md — qeet-id-ios

**The model-neutral instruction file for coding agents, and the source of truth for this repository.**
[CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md) and [.github/copilot-instructions.md](.github/copilot-instructions.md)
point here and add nothing architectural.

## What this repository is

**Qeet ID for iPhone**: the native authenticator that replaces the Expo / React Native app in `qeet-id-auth`.
SwiftUI, Swift 6 with complete strict concurrency, iOS 17 or later, iPhone only. Bundle ID `com.qeetgroup.qeetid`,
display name "Qeet ID". Built on [Qeetrix for iOS](https://github.com/qeetgroup/qeetrix-ios) through Swift Package
Manager; it has no other dependency.

Two jobs:

1. **Sign-in codes (TOTP).** RFC 6238 codes, computed on the phone, for Qeet ID and any other site.
2. **Sign-in approvals.** The phone is linked to a Qeet ID account with a pairing code, then approves or denies each
   sign-in: the person types the 2-digit number from the sign-in screen and confirms with Face ID.

Plus a Face ID app lock, a privacy cover in the app switcher, and AutoFill of codes on iOS 18 and later.

## Context hierarchy

```text
qeet-context (L0)  →  qeet-id-context (L1)  →  qeet-id-server (contract + enforcement)
                                            →  qeet-id-ios (L2, this repository)
```

## Read before changing code

| File | For |
|---|---|
| [qeet-repo.yml](qeet-repo.yml) | Machine-readable identity |
| [docs/llm/architecture-map.md](docs/llm/architecture-map.md) | "Where is X?" |
| [docs/llm/context.md](docs/llm/context.md) | How the app works |
| [docs/llm/boundaries.md](docs/llm/boundaries.md) | What it owns and must not do |
| [docs/llm/workflows.md](docs/llm/workflows.md) | Local server, simulated pushes, adding a screen, releasing |

Product-level flow: `qeet-id-context/FLOWS/mfa.md`. The screens follow the Qeet ID mockups in `qeetgroup/qeet-mockups`
(`products/qeet-id/screens/`, modules 01 to 05, light and dark).

## Targets

| Target | Bundle ID | Folders compiled | Notes |
|---|---|---|---|
| `QeetID` (app) | `com.qeetgroup.qeetid` | `QeetID/`, `Shared/`, `Core/` | iOS 17+ |
| `QeetIDAutoFill` | `….autofill` | `AutoFill/`, `Shared/`, `Core/` | iOS 18+; one-time codes only |
| `QeetIDNotificationService` | `….notification-service` | `NotificationService/`, `Core/` | Enriches the request text |
| `QeetIDTests` | `….tests` | `QeetIDTests/` | Swift Testing, hosted in the app |
| `QeetIDUITests` | `….uitests` | `QeetIDUITests/` | XCUITest |

The project uses **folder-synchronised groups**: a file in a folder is in that folder's targets. Never add file
references to `project.pbxproj` by hand; add the file on disk. Build settings live in `Configs/*.xcconfig`, not in the
project file.

## Rules

### 1. Secrets never enter UI state, a log or a toast
A code's secret lives in the Keychain and is read only by `CodeBook` (in memory, keyed by account) to compute codes.
The device credential is read from `DeviceLinkStore` inside the API call that needs it. Views receive codes and a
`LinkSummary`, never a secret. `os.Logger` lines never interpolate a secret, a code, a pairing code or a push token;
`DeviceLink` redacts itself when printed.

### 2. Keychain items are this-device-only, one per account
`Keychain` writes with `…ThisDeviceOnly` accessibility and `kSecAttrSynchronizable = false`, in the shared access group
`$(AppIdentifierPrefix)com.qeetgroup.qeetid.shared`. Accounts are `WhenUnlockedThisDeviceOnly`; the device link is
`AfterFirstUnlockThisDeviceOnly` so a token refresh can run in the background. Secrets therefore never reach an iCloud
or encrypted backup, and never sync.

### 3. The device credential is a long-lived credential
It approves sign-ins for 180 days after the iPhone was last linked, with no signed-in session. Treat it as a password.
It travels only in JSON bodies (`respond`, `unlink`, `pending`, `push-token`). Unlinking removes it on the server
first; a 401 carrying Qeet ID's own `mfa.push_unauthorized` means the server already forgot it, so it is cleared here
too. **A 401 without that code (a proxy, a captive portal, a gateway) is a network problem and never costs the iPhone
its link.**

### 4. There is no localhost default
Every build talks to `https://api.id.qeet.in`. Only a Debug build accepts `-api-url <url>` at launch, stored in the App
Group so the notification extension follows it. Release builds compile that code out, and only Debug Info.plists allow
local-network HTTP (`INFOPLIST_PREPROCESS`, `QEETID_DEBUG`).

### 5. Linking only with a pairing code, and only on the person's tap
The code comes from the console (Account → Security → Link a phone), scanned, typed or opened from
`qeetidauth://pair?code=…`. A link fills in the code; it never links by itself. Linking never asks for or accepts an
access token.

### 6. Approving always needs the number and a fresh device-owner check
`POST …/respond` carries the typed `number`; the server denies a mismatch (403 `mfa.push_number_mismatch`). Before an
approval is sent, `LocalAuthentication` evaluates `.deviceOwnerAuthentication` with a fresh context, whatever the app
lock is set to. Denying needs neither. Never add a bearer to `respond`: the device credential is the design.

### 7. Qeetrix for every screen
Build from Qeetrix components and tokens (`QeetrixColor`, `QeetrixSpace`, `qeetrixTextStyle`). Icons are Qeetrix icons
in the **sharp** shape (`shape: .sharp`; the default is round); the few Qeetrix lacks are `AppIcon`s generated from
`@qeetrix/icons`' sharp SVGs (`Scripts/generate-app-icons.py`). Ember only for primary actions, focus, the current
item and progress. No uppercase text except group labels. Buttons carry the icon the mockup gives them. When Qeetrix
lacks something, build the smallest app-level piece from Qeetrix tokens (`QeetID/Components/`) and record it for
Qeetrix; never patch or fork Qeetrix here.

### 8. AutoFill stays phishing-resistant
The AutoFill extension asks for Face ID before showing or filling any code. Codes for the requesting site come first;
an account is tied to a site only after the person chose it there, and only then offered in the QuickType bar.

### 9. Concurrency
Swift 6 language mode, complete checking, warnings are errors. UI and models are `@MainActor`; `Core` types are
`Sendable` values or actors. No `@unchecked Sendable` outside tests.

### 10. Administration has its own session, apart from the link
An administrator signs in with a passkey (`AuthenticationServices`, `QeetID/Admin/`) and gets their own Qeet ID session:
the refresh token in the app's own Keychain item (`com.qeetgroup.qeetid.admin`, this device only, never synced, not
shared with the extensions), the access token in memory only; neither reaches UI state, a log or a toast. It is used
only for the administration routes (`AdminAPI`), never for the link or `respond`. Anything that gives or takes access
asks first: a passkey step-up (approve an access request, reactivate) or `.deviceOwnerAuthentication` (suspend, stop
all agents). Passkeys need the `webcredentials:id.qeet.in` associated domain and `id.qeet.in/.well-known/
apple-app-site-association` (qeet-id-website) naming this app's team and bundle ID.

### 11. No ticket keys in code or docs
No tracker keys or tracker links in code, comments, tests or Markdown. Commits and pull requests may name them.

## Commands

```bash
xcodebuild build -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -project QeetID.xcodeproj -scheme QeetID -destination '…' -only-testing:QeetIDTests   # unit tests only
xcrun swift-format lint --strict --recursive Core Shared QeetID AutoFill NotificationService QeetIDTests QeetIDUITests
```

UI tests launch the app with `-ui-testing`, which (Debug builds only) starts from empty storage and stubs Face ID;
`-ui-scan <text>` stands in for the camera, and `QeetIDUITests/StubServer.swift` answers the API on localhost. The
end-to-end test against a local server runs only with `TEST_RUNNER_QEETID_E2E_URL=http://localhost:4001`
([workflows](docs/llm/workflows.md)).

## What CI runs

`.github/workflows/ci.yml` on pull requests into `main`, pushes to `main` and by hand: build, unit tests and UI tests
on an iPhone simulator, and the swift-format lint. `.github/workflows/security.yml`: the gitleaks CLI over the whole
history. macOS minutes are scarce, so nothing runs on pushes to `develop`; run the commands above locally first.
CodeQL is off while the repository is private.

## Branches

Work on `develop`; `main` is what ships. A pull request from `develop` into `main` runs CI.

## Before you finish

```bash
xcodebuild test -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
git diff
```

Push notifications need a physical iPhone and an APNs key; on a simulator, simulate one with
`xcrun simctl push <device> com.qeetgroup.qeetid payload.apns` ([workflows](docs/llm/workflows.md)).

## Escalate rather than proceed

Putting a secret in state, a log or a toast · loosening Keychain accessibility or syncing it · approving without the
number or without device-owner authentication · adding a bearer to `respond` · a localhost or non-production default ·
linking without the person's tap · changing a bundle ID, an App Group or the Keychain group · a new dependency ·
anything that needs another repository changed.
