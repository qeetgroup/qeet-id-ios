# Qeet ID for iOS

The Qeet ID authenticator for iPhone. It shows one-time codes for two-step sign-in, and lets you
approve or deny a Qeet ID sign-in from your phone. It is a native SwiftUI app, built on
[Qeetrix for iOS](https://github.com/qeetgroup/qeetrix-ios).

It replaces the Expo / React Native app in [qeet-id-auth](https://github.com/qeetgroup/qeet-id-auth).
The Android app is [qeet-id-android](https://github.com/qeetgroup/qeet-id-android).

## Status

New repository. The app has not been started yet.

## What it does

- **One-time codes (TOTP):** computed on the phone, so they work offline
- **Push approvals:** approve or deny a sign-in on the phone
- **Linking:** link the phone to an account with a one-time pairing code
- **Biometric lock:** Face ID or Touch ID before codes and approvals

## Stack

| | |
|---|---|
| iOS | 17 or later (the Qeetrix for iOS minimum) |
| Language | Swift 6, SwiftUI |
| Design system | [Qeetrix for iOS](https://github.com/qeetgroup/qeetrix-ios), through Swift Package Manager |
| Secrets | Keychain |
| Backend | [qeet-id-server](https://github.com/qeetgroup/qeet-id-server) |

## Server endpoints the app calls

| Purpose | Endpoint | Credential |
|---|---|---|
| Link the phone | `POST /v1/mfa/push/pairing/claim` | One-time pairing code |
| Read a sign-in request | `GET /v1/mfa/push/challenges/{id}` | Device credential |
| Approve or deny it | `POST /v1/mfa/push/challenges/{id}/respond` | Device credential |
| Unlink the phone | `POST /v1/mfa/push/devices/{id}/unlink` | Device credential |
