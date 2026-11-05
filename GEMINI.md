# GEMINI.md — qeet-id-ios

**Read [AGENTS.md](AGENTS.md) first.** It is the model-neutral instruction file and the source of truth for this
repository; this file only points there.

```text
GEMINI.md  →  AGENTS.md  →  docs/llm/*
```

| File | For |
|---|---|
| [AGENTS.md](AGENTS.md) | Rules, targets, commands, what CI runs |
| [qeet-repo.yml](qeet-repo.yml) | Machine-readable repository identity |
| [docs/llm/context.md](docs/llm/context.md) | How the app works |
| [docs/llm/boundaries.md](docs/llm/boundaries.md) | What it owns, and what it must not touch |
| [docs/llm/workflows.md](docs/llm/workflows.md) | Step-by-step for common changes |
| [docs/llm/architecture-map.md](docs/llm/architecture-map.md) | Where each screen, model and endpoint lives |

Before finishing: `xcodebuild test -project QeetID.xcodeproj -scheme QeetID -destination 'platform=iOS Simulator,name=iPhone 17'`
and `git diff`. Escalate anything that weakens a security rule in AGENTS.md or needs another repository changed.
