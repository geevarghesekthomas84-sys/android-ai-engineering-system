# Architecture

## System Design

The Android AI Engineering System is organized around **skills** — modular, self-contained knowledge packages that AI assistants load on demand to guide development workflows.

### Skill Structure

Each skill follows a consistent layout:

```
skills/<skill-name>/
├── SKILL.md              # Entry point — role definition, capabilities, workflow
├── references/           # Detailed technical guides (patterns, APIs, examples)
│   ├── topic-a.md
│   ├── topic-b.md
│   └── ...
└── examples/             # (optional) Working code samples
```

- **SKILL.md** defines the AI's role, responsibilities, and decision-making framework for that domain
- **references/** contain deep technical content: architecture patterns, code snippets, configuration guides, and best practices
- **examples/** provide working starter code that the AI can use as scaffolding

### Skill Categories

**Platform skills** focus on Android-specific concerns:
- `android-cli` — the core orchestrator, managing ADB, emulators, Gradle builds, and device interactions
- `android-ui-ux-design` — Material 3, Compose, accessibility
- `android-frontend-engineer` — MVVM, navigation, state management
- `android-testing-engineer` — unit, integration, and UI testing
- `app-performance-engineer` — profiling, optimization, benchmarks

**Backend skills** cover server-side development:
- `backend-api-engineer` — NestJS, FastAPI, REST/GraphQL
- `database-offline-sync` — Room, offline-first, sync strategies
- `firebase-supabase-engineer` — BaaS integration

**Cross-cutting skills** span multiple domains:
- `android-security-engineer` — secure storage, auth, network security
- `android-security-lab-builder` — hands-on security labs
- `devops-release-engineer` — CI/CD, versioning, releases
- `ai-integration-engineer` — LLM APIs, on-device ML
- `app-product-architect` — system design, API contracts
- `fullstack-web-engineer` — web companion development

### Scripts

The `scripts/` directory contains PowerShell utilities for common operations:

| Script | Purpose |
|--------|---------|
| `install.ps1` | Install skills to AI assistant directories |
| `sync-agents.ps1` | Synchronize skills across Claude, Gemini, Codex |
| `inspect-device.ps1` | Inspect connected Android device/emulator |
| `build-and-install.ps1` | Build APK and install on device |
| `capture-screenshot.ps1` | Capture emulator screenshot |
| `run-lint-fix.ps1` | Run Android lint with auto-fix |

### Example Apps

**fullstack-taskapp**: A production-pattern task management app demonstrating:
- Android: Kotlin, Jetpack Compose, Material 3, Retrofit, kotlinx.serialization, MVVM
- Backend: NestJS, TypeORM, JWT authentication, bcrypt, Swagger/OpenAPI
- Infrastructure: Docker Compose, PostgreSQL 16, Redis 7
- Testing: Jest integration tests (13 tests), Android unit tests (3 tests), lint

**android-skilltest**: A minimal Android app for validating that skills produce correct, buildable code.

## Design Decisions

1. **Skills over plugins**: Skills are plain Markdown files that any AI assistant can load — no proprietary format or runtime dependency
2. **References over inline code**: Large code samples live in `references/` to keep SKILL.md focused on workflow and decision-making
3. **Environment variables over config files**: All secrets and paths use environment variables with `.env.example` templates
4. **Source-only examples**: Example apps include only source code — no build artifacts, dependencies, or IDE configuration
5. **Portable paths**: All file paths use `$HOME`, `${ANDROID_HOME}`, and similar environment variables instead of hardcoded system paths
