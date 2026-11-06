# Workflows — qeet-id-ios

**Level:** L2 · **Last verified:** 2026-11-06
**Verification scope:** commands run locally with Xcode 27.2 on an iOS 27 simulator.

## Set up

```bash
git clone https://github.com/qeetgroup/qeet-id-ios && cd qeet-id-ios
xcodebuild -resolvePackageDependencies -project QeetID.xcodeproj -scheme QeetID
xcodebuild build -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
```

No team, account or `.env` is needed for the simulator.

## Test

```bash
xcodebuild test -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
Scripts/lint.sh            # swift-format lint; Scripts/lint.sh --fix rewrites
```

## Run against a local Qeet ID server

```bash
# qeet-id-server: make db-up && make dev   (it listens on :4001)
xcrun simctl launch booted com.qeetgroup.qeetid -api-url http://localhost:4001
```

The address is kept (Debug only) in the App Group until the app is launched with `-api-url default`. The
notification service extension reads the same value.

## Run the end-to-end test against a local server

The test plays the browser (sign-up, the console's pairing code, a password sign-in that asks for push) and drives the
app: link, the pending check, the number, Face ID (stubbed in Debug UI tests), approve, deny, a wrong number, expiry,
unlink. It is skipped unless the runner is given the server:

```bash
TEST_RUNNER_QEETID_E2E_URL=http://localhost:4001 xcodebuild test -project QeetID.xcodeproj -scheme QeetID \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:QeetIDUITests/LiveServerE2ETests/testLinkApproveDenyWrongNumberExpireAndUnlink
```

Each run signs up a new `rohan.das.<time>@brightleaffoods.in` account: the server allows five requests in ten minutes
and three denials in an hour per account.

`testANotificationOpensTheRequest` prints `E2E-PUSH-CHALLENGE <id>` and waits for the notification: send it with
`xcrun simctl push` (below) while the test waits.

## Simulate a sign-in request

1. Start a sign-in that asks for push approval, and note the challenge id and the 2-digit number it shows.
2. Write the payload the server sends:

```json
{"aps":{"alert":{"title":"Sign-in request","body":"Someone is signing in to your Qeet ID account. Tap to review."},
 "sound":"default","interruption-level":"time-sensitive","mutable-content":1,"thread-id":"sign-in"},
 "type":"sign_in_request","challenge_id":"<uuid>","action":"sign_in"}
```

3. `xcrun simctl push <device> com.qeetgroup.qeetid payload.apns`, then tap the notification. The notification service
   extension reads the request and writes "from Chrome on macOS" into the body; with an unknown id it leaves the
   server's text.

Without push (a simulator, or a server with no APNs key), a linked app finds waiting requests itself: when it comes to
the foreground, and on pull to refresh on Accounts (`POST /v1/mfa/push/devices/{id}/pending`).

## Add a screen

1. Add the file under the feature's folder in `QeetID/` (folder-synchronised: no project edit).
2. Build it from Qeetrix components; icons with `shape: .sharp`.
3. Add its route to `Route` (pushed) or `AppModal` (full-screen) and present it from `RootView`.
4. Strings are English source keys; the String Catalog picks them up.
5. Add a UI test in `QeetIDUITests/`, then run the tests and the lint.

## Release

1. Put the team in `Configs/Signing.xcconfig.local` (ignored by git).
2. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Configs/Project.xcconfig`.
3. Move `[Unreleased]` in `CHANGELOG.md` under the new version.
4. Product › Archive in Xcode (Release uses the production APNs environment).
