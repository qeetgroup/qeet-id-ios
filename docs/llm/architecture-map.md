# Architecture Map — qeet-id-ios

**Level:** L2 · **Last verified:** 2026-11-06
**Verification scope:** every path confirmed to exist.

| Need | Path |
|---|---|
| Repository identity | [`qeet-repo.yml`](../../qeet-repo.yml) |
| Agent instructions | [`AGENTS.md`](../../AGENTS.md) |
| Build settings, Info.plists, entitlements | `Configs/` |
| The project (folder-synchronised) | `QeetID.xcodeproj` |
| App entry and window | `QeetID/App/` |
| Accounts home | `QeetID/Accounts/` |
| Settings | `QeetID/Settings/` |
| AutoFill credential provider | `AutoFill/` |
| Notification service extension | `NotificationService/` |
| Shared identifiers | `Core/AppIdentity.swift` |
| Unit tests / UI tests | `QeetIDTests/`, `QeetIDUITests/` |
