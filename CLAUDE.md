# CLAUDE.md — qeet-id-ios

**Read [AGENTS.md](AGENTS.md) first.** It is the model-neutral instruction file and the source of truth for this
repository. This file adds only Claude-specific guidance.

```text
CLAUDE.md  →  AGENTS.md  →  docs/llm/*
```

## Canonical context

| File | For |
|---|---|
| [qeet-repo.yml](qeet-repo.yml) | Machine-readable repository identity |
| [AGENTS.md](AGENTS.md) | **Rules, targets, commands, what CI runs** |
| [docs/llm/context.md](docs/llm/context.md) | How the app works |
| [docs/llm/boundaries.md](docs/llm/boundaries.md) | What it owns, and what it must not touch |
| [docs/llm/workflows.md](docs/llm/workflows.md) | Step-by-step for common changes |
| [docs/llm/architecture-map.md](docs/llm/architecture-map.md) | "Where is X?": the fastest path to a file |

Parent context: **L0** `qeetgroup/qeet-context` · **L1** `qeetgroup/qeet-id-files`.

## The things most likely to trip you up here

1. **Folder-synchronised groups.** Add files on disk; never edit `project.pbxproj` to add one. A file in `Core/` is
   compiled into the app and both extensions; `Shared/` into the app and AutoFill.
2. **Qeetrix icons default to the round shape.** Pass `shape: .sharp` everywhere.
3. **Secrets never reach SwiftUI state, logs or toasts** (AGENTS.md rule 1). Views get codes, never secrets.
4. **No localhost default.** `-api-url` works only in Debug builds.
5. **Approving needs the number and Face ID**, always. Never add a bearer to `respond`.
6. **Warnings are errors** in every target, under Swift 6 complete concurrency checking.

## Working style

- Read before editing; match the neighbouring file's shape.
- Use the architecture map instead of guessing a path.
- Verify with build, tests and lint; screenshots are not verification.
- Do not read `.env` or secret files into anything you write.

## Finishing a change

```bash
xcodebuild test -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'
git diff
```

## Escalate rather than proceed

Stop and report if a task would weaken a security control in AGENTS.md, change a bundle ID or entitlement, add a
dependency, or require modifying another repository (Qeetrix for iOS included).
