# GitHub Copilot — qeet-id-ios

**Canonical instructions: [`AGENTS.md`](../AGENTS.md).** This file is a summary; it adds no architecture.

## Repository

**Qeet ID for iPhone**, the native authenticator: offline sign-in codes (RFC 6238) and approving Qeet ID sign-ins
with number matching and Face ID, plus AutoFill of codes on iOS 18. SwiftUI, Swift 6 (complete concurrency checking,
warnings as errors), iOS 17+, built on Qeetrix for iOS. Targets: the app, an AutoFill credential provider, a
notification service extension, unit tests and UI tests.

## Hard rules

- Secrets (code secrets, the device credential, pairing codes, push tokens) never in SwiftUI state, logs or toasts.
- Keychain items are `…ThisDeviceOnly`, never synchronizable, in the shared access group.
- No localhost default: production unless a Debug build is launched with `-api-url`.
- Approving needs the typed number and fresh `.deviceOwnerAuthentication`; no bearer on `respond`.
- Qeetrix components and tokens for every screen; Qeetrix icons with `shape: .sharp`.
- Add files on disk (folder-synchronised groups); build settings live in `Configs/*.xcconfig`.
- No tracker keys in code or docs.

See [`docs/llm/architecture-map.md`](../docs/llm/architecture-map.md) to find a file.
