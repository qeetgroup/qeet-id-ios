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
