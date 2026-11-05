# Changelog

All notable changes to Qeet ID for iPhone are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The Xcode project: the app, an AutoFill credential provider, a notification service extension, unit tests and UI
  tests, on folder-synchronised groups with every build setting in `Configs/*.xcconfig`. Swift 6 language mode with
  complete concurrency checking and warnings as errors.
- Qeetrix for iOS from 0.1.0 through Swift Package Manager.
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
