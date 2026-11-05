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
