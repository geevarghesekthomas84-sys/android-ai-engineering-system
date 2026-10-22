# Changelog

## v3.0.0 — Multi-Skill Android Engineering System (2026-10-21)

### Overview
Expansion from single Android CLI skill to a 14-skill modular AI-powered
development system covering the full Android and full-stack development lifecycle.

### New Specialized Skills Created
- `android-ui-ux-design` — Material 3 design system, responsive layouts, motion, accessibility
- `android-frontend-engineer` — Kotlin/Compose architecture, Navigation3, MVVM/MVI, Hilt, networking
- `android-testing-engineer` — JUnit, Compose UI tests, Espresso, screenshot testing, CI automation
- `app-performance-engineer` — Startup, Compose perf, memory, APK size, benchmarking
- `backend-api-engineer` — NestJS/FastAPI, REST, auth, PostgreSQL, Docker
- `database-offline-sync` — Room, DataStore, migrations, offline-first, sync, conflict resolution
- `firebase-supabase-engineer` — Firebase Auth/Firestore/FCM, Supabase PostgreSQL/Realtime
- `android-security-engineer` — OWASP MASVS/MASTG, threat modeling, secure storage, network security
- `android-security-lab-builder` — Intentionally vulnerable apps, CTF challenges, security training
- `devops-release-engineer` — CI/CD, signing, GitHub Actions, Docker, Play Console, monitoring
- `ai-integration-engineer` — LLM APIs, chat UI, streaming, RAG, on-device ML, AI safety
- `app-product-architect` — Requirements, system design, tech selection, project planning
- `fullstack-web-engineer` — React/Next.js, Tailwind, admin dashboards, web APIs

### Cross-Skill Orchestration
- Android CLI skill now serves as entry point with orchestration table
- Workflow routing for complex multi-domain requests
- Each skill has focused trigger conditions and capabilities

### Full-Stack Demo Project
- Complete task-manager app demonstrating 8+ skills working together
- Android: Kotlin + Compose Material 3 + Retrofit + MVVM (assembleDebug PASS, 18.53 MB)
- Backend: NestJS + TypeORM + JWT auth + Swagger (tsc compile PASS)
- Infrastructure: Docker Compose with PostgreSQL 16 + Redis 7
- 3/3 unit tests passing
- Located at `fullstack-demo/` in project directory

### Validation
- `validate-v3-skills.ps1` — 42/42 checks passed, 0 failures, 0 warnings
- All frontmatter valid, all reference counts met, no empty files
- QUALITY-REPORT-v3.md with complete per-skill feature inventory

### Statistics
- 14 skills total (1 enhanced + 13 new)
- 97 reference documents with real code examples
- 126 files, 1.15 MB of implementation-ready content
- 2 test applications (v2.0 SkillTest + v3.0 TaskApp demo)

---

## v2.0.0 — Enhanced Android Development Skill (2026-10-21)

### Overview
Complete upgrade from single-file CLI reference to comprehensive, production-grade
Android development skill with modular architecture, automation scripts, and
example projects.

### What's New

#### Skill Architecture
- Modular structure with `references/`, `scripts/`, and `examples/` directories.
- Main SKILL.md serves as concise entry point with progressive disclosure.
- 12 reference documents covering all Android development areas.
- 4 PowerShell automation scripts with input validation and error handling.
- 2 example project scaffolds (basic Compose, security-hardened).

#### Android Application Development (Phase 2)
- Kotlin coding standards and patterns.
- Jetpack Compose + Material 3 theming, layouts, and components.
- MVVM + Clean Architecture with full layer structure.
- Hilt dependency injection setup and patterns.
- Navigation Compose with type-safe routes.
- Room Database with DAO patterns and offline-first repository.
- Retrofit + OkHttp API layer with serialization.
- DataStore preferences.
- Responsive layouts with WindowSizeClass.
- Accessibility guidelines.

#### Build Automation (Phase 2)
- Complete Gradle build system reference with version catalog.
- Build variants and product flavors.
- Signing configuration (with secure key management).
- Common Gradle commands and dependency conflict resolution.
- `build-debug.ps1` script for automated builds.

#### AI Development Workflow (Phase 3)
- 10-step autonomous development workflow in SKILL.md.
- Environment detection and tool path resolution.
- Critical rules for honest reporting and safe operations.
- Quick reference table for common tasks.

#### Security Engineering (Phase 4)
- OWASP MASVS-aligned security practices.
- AndroidManifest.xml security review guidance.
- Network Security Configuration with certificate pinning.
- Android Keystore and EncryptedSharedPreferences.
- WebView security hardening.
- Deep link and intent validation.
- Security review checklist (static and dynamic).
- Secure example project with all protections applied.

#### Testing & QA (Phase 5)
- JUnit unit testing with coroutines and Flow (Turbine).
- Compose UI testing patterns.
- Espresso instrumentation tests.
- Room database testing.
- Test execution commands and report locations.
- CI/CD pipeline with GitHub Actions.
- Accessibility testing guidance.

#### Performance (Phase 5)
- Startup performance measurement and optimization.
- Compose recomposition optimization.
- Memory leak detection and prevention.
- Network and database performance.
- APK size optimization with R8/ProGuard.
- Build performance tuning.

#### Troubleshooting (Phase 5)
- Common Gradle build errors with solutions.
- Kotlin compilation error guide.
- Compose-specific errors.
- Device and ADB troubleshooting.
- Runtime error solutions.
- Environment setup issues.

#### Automation Scripts (Phase 6)
- `check-environment.ps1` — Detects all Android tools, SDK components, devices.
- `build-debug.ps1` — Builds APK with validation, timing, optional install.
- `run-tests.ps1` — Runs unit or instrumentation tests with reports.
- `inspect-device.ps1` — Reports device info, screen, storage, battery.

#### Agent Capabilities (Phase 7)
- Environment detection before any task.
- Known tool paths for Windows with fallback resolution.
- Rules preventing false success claims.
- Inspect-before-modify workflow.
- Integration with `android docs search` for current API info.

### Preserved from v1.0
- All original Android CLI command documentation.
- Device interaction rules and workflow.
- Journey test format and evaluation.
- UI layout dump and screen capture instructions.
- Doc searching via `android docs`.

### Breaking Changes
- None. Original SKILL.md content preserved and enhanced.
- Backup of v1.0 SKILL.md created before modification.

### Environment Notes
- Android CLI not currently in PATH — install instructions included.
- JAVA_HOME and ANDROID_HOME not set — scripts handle this gracefully.
- Full tool paths documented for the current Windows environment.
