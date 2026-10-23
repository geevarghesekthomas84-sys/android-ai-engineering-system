# Changelog

All notable changes to the Android AI Engineering System are documented here.

This project follows [Semantic Versioning](https://semver.org/).

## [3.2.1] - 2026-10-23

### Fixed
- **PowerShell CI**: Pre-declare `$tokens` and `$parseErrors` variables before `[ref]` — fixes `[ref] cannot be applied to a variable that does not exist` on pwsh/Linux
- **Security scan**: Scope credential grep to `skills/`, `scripts/`, `examples/` directories — eliminates false positives from workflow and test files matching their own patterns
- **Backend CI**: Upgrade `@nestjs/swagger` from `^8.0.0` to `^11.0.0` to resolve peer-dependency conflict with `@nestjs/common@^11`
- **Backend CI**: Generate and commit `package-lock.json` — fixes `cache-dependency-path` resolution failure
- **Backend CI**: Switch `npm install` to `npm ci` for reproducible builds
- **All workflows**: Add `workflow_call` trigger so the release gate can invoke each workflow as a reusable workflow

## [3.2.0] - 2026-10-23

### Added
- **GitHub Actions CI/CD** — 7 workflow files:
  - `skills-validation.yml` — validates all 14 skill structures
  - `docs-lint.yml` — Markdown lint and internal link checking
  - `security-scan.yml` — secret, credential, and privacy scanning + npm audit
  - `backend-tests.yml` — TypeScript compilation + Jest integration tests with PostgreSQL service
  - `android-build.yml` — Gradle build, unit tests, and lint for both example apps
  - `powershell-check.yml` — syntax validation and installer dry-run
  - `release-gate.yml` — combined release readiness gate
- **Skill Evaluation Framework** (`tests/skill-eval/`):
  - `eval-cases.json` — 13 deterministic + 5 AI behavior test cases
  - `run-eval.sh` — automated evaluation runner
  - Clear separation of deterministic checks vs. AI behavior evaluations
- **Improved Installer** (`scripts/install.ps1`):
  - `Install`, `Upgrade`, `Backup`, `Uninstall` actions
  - Automatic backup before upgrade/uninstall
  - Multi-target support (Claude, Gemini, Codex, All)
  - `-WhatIf` dry-run for all actions
- **Security Hardening**:
  - Startup validation for `JWT_SECRET` and `DATABASE_URL`
  - Configurable CORS origin via `CORS_ORIGIN` env var
  - No insecure secret fallbacks anywhere
- **VERSION** file for semantic version tracking
- **CHANGELOG.md** for release history

### Changed
- Upgraded `install.ps1` from basic copy to full lifecycle manager
- Backend `main.ts` now fails fast on missing required env vars

### Security
- All credentials externalized to environment variables
- Cross-user task isolation verified (all queries filter by userId)
- bcrypt password hashing confirmed
- No hardcoded paths, credentials, or personal data in any file
- CI secret scanning runs on every push and PR

## [3.1.0] - 2026-10-22

### Added
- Initial public release with 14 AI engineering skills
- Fullstack TaskApp example (Android + NestJS + PostgreSQL + Redis)
- Android SkillTest example app
- 7 PowerShell utility scripts
- Professional README with mermaid diagrams
- MIT License, SECURITY.md, CONTRIBUTING.md
- Comprehensive .gitignore and .env.example

### Verified
- 13/13 backend integration tests passing
- 3/3 Android unit tests passing
- 0 Android lint errors
- Full CRUD cycle verified: Android UI → NestJS → PostgreSQL
