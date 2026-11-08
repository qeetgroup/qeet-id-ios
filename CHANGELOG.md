# Changelog

All notable changes to Qeet ID for iPhone are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Administration**: an administrator signs in with their passkey and gets their own session, apart from the link:
  access requests to approve (after a fresh passkey check) or deny with a reason, critical events of the last day, and
  two emergency actions, suspend a person and stop all AI agents, each behind Face ID. Reached from Settings.
- **Requests waiting**: when more than one sign-in is waiting, one list with each request's time left and Deny all.
- **Move to a new iPhone**, **About and help** and **Update required** (shown when Qeet ID answers 426).

### Changed

- Every screen redrawn to the Qeet ID mockups: the keyhole icon on Qeet orange (app icon and in-app mark), its rings
  and seals, settings-style ruled groups, result pages for approved, denied, ended and linked, scanning that shows what
  was found before adding it, and a notification that names the browser and place.
- **Launch** as the mockup draws it: the 112 pt app icon in the middle and "from Qeet Group" at the foot, in light
  and dark, on every iPhone and iPad (`LaunchScreen.storyboard`; the images come from
  `Scripts/generate-launch-screen.py`, the words as Qeet Sans's outlines).
- Settings' switches (the lock, hidden codes) are the bare Qeetrix switch at the row's end, so each label shows
  once; the setup steps show the progress bar alone, with the step for VoiceOver.
- Type the setup key's code settings as the mockup draws them: each setting is a row with its name at the start and
  a small segmented choice at the end ("30 s", not "30 seconds"), under the name only when the line is too narrow.

- The Xcode project: the app, an AutoFill credential provider, a notification service extension, unit tests and UI
  tests, on folder-synchronised groups with every build setting in `Configs/*.xcconfig`. Swift 6 language mode with
  complete concurrency checking and warnings as errors.
- Qeetrix for iOS from 0.3.0 through Swift Package Manager. Its bottom action bar, list rows with a code and a
  monogram tile, flush-row card, copy, rename dialog with text fields, number-match input, accordion summary, AutoFill
  code that fills on a tap, empty-state tones and icons replace the app's own stand-ins. Every icon is the mockups'
  own Qeetrix icon (qr-code on the scan actions, an icon-only Switch organisation button, laptop, monitor, globe,
  bell-ring, bot-off, download, rotate-ccw, shield-alert); the app draws none itself. Paste stays the system Paste
  button, which reads the clipboard only when tapped and without the "Allow Paste" prompt.
- The app icon (light, dark and tinted) and the in-app Q-key mark.
- CI on pull requests into `main` and pushes to `main`: build, tests, lint and a gitleaks scan.
- Foundations: Keychain storage (`…ThisDeviceOnly`, never synchronizable, one item per account in the access group
  shared with AutoFill); RFC 6238 codes with CryptoKit (SHA-1, SHA-256, SHA-512; 6 or 8 digits); RFC 4648 Base32;
  `otpauth://` links; pairing codes; the API client for `/v1/mfa/push/*` with the server's clock correction; the
  device link; Face ID, Touch ID or passcode checks and the app lock; String Catalogs for every target
  (`Scripts/sync-strings.sh`).
- Getting started: Welcome, Lock Qeet ID (step 1 of 2) and the notifications primer (step 2 of 2).
- The Locked screen, asking for Face ID by itself when the app opens or returns from the background, and a privacy
  cover whenever the app isn't active, both in a window of their own above sheets and alerts, so the app switcher
  never shows a code.
- Sign-in codes: the Accounts screen (large title, search, each account's code with the time left, tap to copy for a
  minute on this iPhone only), the empty state, Add account with the QR scanner (camera, torch, camera access off)
  and the setup-key sheet with Advanced settings, the context menu (Copy Code, Rename, Delete Account), Rename with
  the system alert and Delete with the action sheet.
- AutoFill (iOS 18 and later): the AutoFill codes page and the credential provider's "Choose a code" sheet, with the
  site's codes first, Face ID before any code is shown or filled, and sites remembered only once the person chose an
  account there.
- Sign-in approvals: Link this iPhone, the pairing-code scanner (refusing anything that isn't a pairing code), Name
  this iPhone (scanned or typed code) and iPhone linked, showing the account's email when the server returns it;
  `qeetidauth://pair?code=…` links fill in the code and wait for the person's tap.
- APNs registration (the token in hex, sent again when it changes, tolerating a server without the route),
  notification taps and requests arriving in the foreground, and a notification service extension that writes the
  request's text and adds the browser and system, keeping the server's text on any failure.
- The request screen: where and what, the 2-digit number on the number pad, the countdown, Deny or Approve with a
  fresh Face ID or passcode check, and the outcomes (approved, blocked with the next step, ended for a wrong number,
  an expired or answered request) and a load error with Try again.
- Waiting requests are fetched when the app comes to the foreground and on pull to refresh, and the newest opens as a
  notification tap would.
- The Accounts screen's Sign-in approvals row, and the problems that stop requests reaching the iPhone: notifications
  off, offline, and a link the server no longer accepts.
- Settings: the linked account (its email, this iPhone's name and how long it stays linked) with Unlink this iPhone
  behind the system alert, the lock switch (which asks for Face ID to turn it on or off), Hide codes until tapped,
  AutoFill codes with its status (iOS 18 and later), and Help and privacy with the version.
- Hardening: no secret is read and no code is kept while the app is locked or in the background; the main window is
  hidden from VoiceOver under the shield; VoiceOver actions on each account (Copy Code, Rename, Delete Account); a
  privacy manifest (no tracking, no data collected); Release builds have no App Transport Security exception and none
  of the Debug hooks; signing placeholders for the owner's team in `Configs/Signing.xcconfig`.
- Tests: unit tests in Swift Testing (RFC 6238 and RFC 4226 vectors, RFC 4648 Base32, `otpauth://` links, pairing
  codes, site matching, user agents and server dates, the Keychain stores and their accessibility, the API client
  against `URLProtocol` stubs, and the models behind the screens); UI tests for every flow, with a stub of the API on
  localhost; and an end-to-end test against a local Qeet ID server (skipped unless `TEST_RUNNER_QEETID_E2E_URL` is set).
- Only a 401 carrying Qeet ID's own `mfa.push_unauthorized` reads as "this iPhone is no longer linked"; a bare 401 from
  a proxy, captive portal or gateway is a network problem and keeps the link.
