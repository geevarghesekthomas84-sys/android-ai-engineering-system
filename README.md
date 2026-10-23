<p align="center">
  <img src="docs/banner.svg" alt="Android AI Engineering System" width="100%"/>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"/></a>
  <img src="https://img.shields.io/badge/Version-3.2-blue.svg" alt="Version 3.2"/>
  <img src="https://img.shields.io/badge/Skills-14-orange.svg" alt="14 Skills"/>
  <a href="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/skills-validation.yml"><img src="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/skills-validation.yml/badge.svg" alt="Skill Validation"/></a>
  <a href="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/security-scan.yml"><img src="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/security-scan.yml/badge.svg" alt="Security Scan"/></a>
  <a href="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/backend-tests.yml"><img src="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/backend-tests.yml/badge.svg" alt="Backend Tests"/></a>
  <a href="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/android-build.yml"><img src="https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system/actions/workflows/android-build.yml/badge.svg" alt="Android Build"/></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Kotlin-2.0-7F52FF.svg?logo=kotlin&logoColor=white" alt="Kotlin 2.0"/>
  <img src="https://img.shields.io/badge/Jetpack%20Compose-Material%203-4285F4.svg?logo=jetpackcompose&logoColor=white" alt="Jetpack Compose"/>
  <img src="https://img.shields.io/badge/NestJS-10-E0234E.svg?logo=nestjs&logoColor=white" alt="NestJS"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED.svg?logo=docker&logoColor=white" alt="Docker"/>
</p>

<p align="center">
  <b>14 specialized AI engineering skills for professional Android development</b><br/>
  Full-stack coverage: UI/UX, Frontend, Backend, Security, DevOps, AI Integration, and more.
</p>

---

## What Is This?

The **Android AI Engineering System** is a modular collection of AI-powered engineering skills designed for [Claude Code](https://claude.com/claude-code) and compatible AI assistants. Each skill transforms an AI into a specialized engineer — from a UI/UX designer who knows Material 3 to a security engineer who can build penetration testing labs.

Instead of generic AI responses, you get **expert-level guidance** with production-ready code patterns, architecture decisions, and battle-tested workflows.

### Key Features

- **14 domain-specific skills** — each with a dedicated role, reference library, and decision framework
- **Full-stack coverage** — Android frontend through backend APIs, databases, CI/CD, and cloud
- **Working examples** — a complete TaskApp (Android + NestJS + PostgreSQL + Redis) with verified end-to-end CRUD
- **Portable installation** — one script to deploy skills to Claude Code, Gemini, or Codex
- **Security-first** — all secrets externalized, all paths portable, audited for publication

---

## Skill Catalog

<table>
<thead>
<tr><th>#</th><th>Skill</th><th>Domain</th><th>What It Does</th></tr>
</thead>
<tbody>
<tr><td>1</td><td><b>android-cli</b></td><td>Core</td><td>ADB, emulator management, Gradle builds, device inspection — the central orchestrator</td></tr>
<tr><td>2</td><td><b>android-ui-ux-design</b></td><td>Design</td><td>Material 3, Compose layouts, accessibility, theming, motion &amp; animation</td></tr>
<tr><td>3</td><td><b>android-frontend-engineer</b></td><td>Frontend</td><td>MVVM, state management, Navigation3, dependency injection, networking</td></tr>
<tr><td>4</td><td><b>android-testing-engineer</b></td><td>Quality</td><td>JUnit, Espresso, UI Automator, Compose testing, screenshot tests, CI</td></tr>
<tr><td>5</td><td><b>app-performance-engineer</b></td><td>Performance</td><td>Profiling, startup optimization, memory management, APK size, benchmarks</td></tr>
<tr><td>6</td><td><b>backend-api-engineer</b></td><td>Backend</td><td>NestJS, FastAPI, REST/GraphQL, authentication, database patterns, Docker</td></tr>
<tr><td>7</td><td><b>database-offline-sync</b></td><td>Data</td><td>Room, offline-first architecture, sync strategies, migrations, caching</td></tr>
<tr><td>8</td><td><b>firebase-supabase-engineer</b></td><td>Cloud</td><td>Firebase Auth, Firestore, Supabase, cloud functions, push notifications</td></tr>
<tr><td>9</td><td><b>android-security-engineer</b></td><td>Security</td><td>Secure storage, network security, auth hardening, code obfuscation, threat modeling</td></tr>
<tr><td>10</td><td><b>android-security-lab-builder</b></td><td>Security</td><td>Hands-on security labs: crypto, storage, network, injection, CTF design</td></tr>
<tr><td>11</td><td><b>devops-release-engineer</b></td><td>DevOps</td><td>GitHub Actions CI/CD, signing, versioning, rollback, monitoring</td></tr>
<tr><td>12</td><td><b>ai-integration-engineer</b></td><td>AI/ML</td><td>LLM APIs (Claude, GPT, Gemini), on-device ML, RAG, streaming, cost optimization</td></tr>
<tr><td>13</td><td><b>app-product-architect</b></td><td>Architecture</td><td>System design, API contracts, data modeling, tech stack selection, scalability</td></tr>
<tr><td>14</td><td><b>fullstack-web-engineer</b></td><td>Web</td><td>Next.js, React, Tailwind, web auth, deployment — web companion to mobile</td></tr>
</tbody>
</table>

---

## System Architecture

The system is organized into three tiers of skills that compose together through an AI assistant:

```mermaid
graph TB
    subgraph AI["AI Assistant Layer"]
        direction LR
        C["Claude Code / Gemini / Codex"]
    end

    subgraph Platform["Platform Skills"]
        direction LR
        CLI["android-cli<br/><i>Core Orchestrator</i>"]
        UI["android-ui-ux-design<br/><i>Material 3 + Compose</i>"]
        FE["android-frontend-engineer<br/><i>MVVM + Navigation</i>"]
        TEST["android-testing-engineer<br/><i>Unit + UI Tests</i>"]
        PERF["app-performance-engineer<br/><i>Profiling + Optimization</i>"]
    end

    subgraph Backend["Backend & Data Skills"]
        direction LR
        API["backend-api-engineer<br/><i>NestJS + FastAPI</i>"]
        DB["database-offline-sync<br/><i>Room + Sync</i>"]
        FIRE["firebase-supabase-engineer<br/><i>BaaS Integration</i>"]
        WEB["fullstack-web-engineer<br/><i>Next.js + React</i>"]
    end

    subgraph Cross["Cross-Cutting Skills"]
        direction LR
        SEC["android-security-engineer<br/><i>Auth + Encryption</i>"]
        LAB["android-security-lab-builder<br/><i>Hands-on Labs</i>"]
        DEV["devops-release-engineer<br/><i>CI/CD + Releases</i>"]
        AIE["ai-integration-engineer<br/><i>LLM + ML APIs</i>"]
        ARCH["app-product-architect<br/><i>System Design</i>"]
    end

    AI --> Platform
    AI --> Backend
    AI --> Cross
    Platform --> Cross
    Backend --> Cross

    style AI fill:#1a1a2e,stroke:#3DDC84,stroke-width:2px,color:#e6edf3
    style Platform fill:#0d1117,stroke:#00BCD4,stroke-width:2px,color:#e6edf3
    style Backend fill:#0d1117,stroke:#7C4DFF,stroke-width:2px,color:#e6edf3
    style Cross fill:#0d1117,stroke:#FF6D00,stroke-width:2px,color:#e6edf3
```

### Skill Internal Structure

Every skill follows a consistent layout:

```
skills/<skill-name>/
├── SKILL.md              # Entry point — role, capabilities, decision framework
├── references/           # Deep technical guides with code examples
│   ├── topic-a.md
│   ├── topic-b.md
│   └── ...
└── examples/             # (optional) Working starter code
```

---

## Development Workflow

This is how the skills integrate into a typical Android development cycle:

```mermaid
flowchart LR
    A["Requirement<br/>Analysis"] --> B["Architecture<br/>Design"]
    B --> C["UI/UX<br/>Design"]
    C --> D["Frontend<br/>Development"]
    D --> E["Backend<br/>Development"]
    E --> F["Testing &<br/>Security"]
    F --> G["CI/CD &<br/>Release"]

    A -.- S1["app-product-architect"]
    B -.- S2["app-product-architect<br/>database-offline-sync"]
    C -.- S3["android-ui-ux-design"]
    D -.- S4["android-frontend-engineer<br/>android-cli"]
    E -.- S5["backend-api-engineer<br/>firebase-supabase-engineer"]
    F -.- S6["android-testing-engineer<br/>android-security-engineer"]
    G -.- S7["devops-release-engineer"]

    style A fill:#7C4DFF,stroke:#7C4DFF,color:#fff
    style B fill:#3F51B5,stroke:#3F51B5,color:#fff
    style C fill:#00BCD4,stroke:#00BCD4,color:#fff
    style D fill:#3DDC84,stroke:#3DDC84,color:#000
    style E fill:#FF6D00,stroke:#FF6D00,color:#fff
    style F fill:#E91E63,stroke:#E91E63,color:#fff
    style G fill:#FFD600,stroke:#FFD600,color:#000
```

### Workflow in Practice

1. **Analyze** — `app-product-architect` helps break down requirements, choose tech stacks, and define API contracts
2. **Design** — `android-ui-ux-design` produces Material 3 layouts with accessibility and responsive breakpoints
3. **Build Frontend** — `android-frontend-engineer` scaffolds MVVM with Compose, Navigation, and DI
4. **Build Backend** — `backend-api-engineer` sets up NestJS/FastAPI with auth, TypeORM, and Docker
5. **Test** — `android-testing-engineer` writes unit, integration, and UI tests; `android-security-engineer` audits
6. **Ship** — `devops-release-engineer` configures CI/CD, signing, versioning, and rollback

Throughout: `android-cli` orchestrates builds, emulator, and ADB; `ai-integration-engineer` wires up LLM features; `app-performance-engineer` optimizes.

---

## Fullstack TaskApp — Data Flow

The included example app demonstrates a complete data flow from the Android UI layer through to PostgreSQL:

```mermaid
sequenceDiagram
    participant U as User
    participant App as Android App<br/>(Kotlin + Compose)
    participant VM as TaskViewModel<br/>(MVVM)
    participant API as Retrofit<br/>(OkHttp)
    participant BE as NestJS Backend<br/>(Express + TypeORM)
    participant PG as PostgreSQL 16<br/>(Docker)
    participant RD as Redis 7<br/>(Docker)

    Note over U,RD: Registration & Login
    U->>App: Tap "Register"
    App->>VM: register(email, name, password)
    VM->>API: POST /auth/register
    API->>BE: HTTP Request
    BE->>PG: INSERT INTO users (bcrypt hash)
    PG-->>BE: User record
    BE-->>API: { token, user }
    API-->>VM: AuthResponse
    VM-->>App: Update UI state
    App-->>U: Show Task List

    Note over U,RD: Create Task
    U->>App: Tap FAB → Fill form
    App->>VM: createTask(title, desc)
    VM->>API: POST /tasks (JWT header)
    API->>BE: Authenticated request
    BE->>BE: Validate JWT
    BE->>PG: INSERT INTO tasks
    PG-->>BE: Task record
    BE-->>API: { task }
    API-->>VM: TaskDto
    VM-->>App: Append to task list
    App-->>U: Show new task

    Note over U,RD: Toggle Status
    U->>App: Tap checkbox
    App->>VM: toggleTask(id)
    VM->>API: PATCH /tasks/{id}
    API->>BE: { status: "completed" }
    BE->>PG: UPDATE tasks SET status
    PG-->>BE: Updated record
    BE-->>API: { task }
    API-->>VM: Updated TaskDto
    VM-->>App: Update task in list
    App-->>U: Show strikethrough + check
```

### Fullstack Architecture Diagram

```mermaid
graph TB
    subgraph Android["Android Emulator"]
        Compose["Jetpack Compose UI<br/><i>Material 3 + LazyColumn</i>"]
        ViewModel["TaskViewModel<br/><i>StateFlow + MVVM</i>"]
        Repo["TaskRepository<br/><i>Token Management</i>"]
        Retrofit["Retrofit + OkHttp<br/><i>kotlinx.serialization</i>"]
    end

    subgraph Server["NestJS Backend (Port 3000)"]
        Controller["Controllers<br/><i>Auth + Tasks + Users</i>"]
        Service["Services<br/><i>Business Logic</i>"]
        Guard["JWT Auth Guard<br/><i>@nestjs/jwt</i>"]
        ORM["TypeORM<br/><i>Entity Mapping</i>"]
    end

    subgraph Data["Docker Containers"]
        PG["PostgreSQL 16<br/><i>users + tasks tables</i>"]
        Redis["Redis 7<br/><i>Session Cache</i>"]
    end

    Compose --> ViewModel
    ViewModel --> Repo
    Repo --> Retrofit
    Retrofit -->|"HTTP via 10.0.2.2:3000"| Controller
    Controller --> Guard
    Guard --> Service
    Service --> ORM
    ORM --> PG
    Service -.-> Redis

    style Android fill:#1a1a2e,stroke:#3DDC84,stroke-width:2px,color:#e6edf3
    style Server fill:#1a1a2e,stroke:#E0234E,stroke-width:2px,color:#e6edf3
    style Data fill:#1a1a2e,stroke:#2496ED,stroke-width:2px,color:#e6edf3
```

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/auth/register` | No | Register new user (email, name, password) |
| `POST` | `/auth/login` | No | Login and receive JWT token |
| `GET` | `/tasks` | JWT | List tasks (paginated) |
| `POST` | `/tasks` | JWT | Create a new task |
| `GET` | `/tasks/:id` | JWT | Get a single task |
| `PATCH` | `/tasks/:id` | JWT | Update task (status, priority) |
| `DELETE` | `/tasks/:id` | JWT | Delete a task |
| `GET` | `/users` | JWT | List users |

---

## Getting Started

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Android Studio](https://developer.android.com/studio) | Latest + SDK 35+ | Android development & emulator |
| [Node.js](https://nodejs.org/) | 20+ | Backend development |
| [Docker](https://www.docker.com/) | Latest | PostgreSQL & Redis containers |
| [Claude Code](https://claude.com/claude-code) | Latest | AI assistant (or Gemini/Codex) |

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system.git
cd android-ai-engineering-system

# 2. Install skills to your AI assistant
# Option A: Copy manually (Linux/macOS)
cp -r skills/* ~/.claude/skills/

# Option B: Use the installation script (Windows PowerShell)
./scripts/install.ps1 -WhatIf    # Preview what will be installed
./scripts/install.ps1             # Install to Claude Code
./scripts/install.ps1 -Target All # Install to Claude + Gemini + Codex
```

### Run the Fullstack Example

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env — set POSTGRES_PASSWORD and JWT_SECRET

# 2. Start database containers
cd examples/fullstack-taskapp/docker
docker compose up -d

# 3. Start the backend
cd ../backend
npm install
npm run build
node dist/main.js
# Backend running on http://localhost:3000
# Swagger docs at http://localhost:3000/api

# 4. Open Android project in Android Studio
# Open examples/fullstack-taskapp/android/
# Run on emulator (API 33+)
```

---

## Project Structure

```
android-ai-engineering-system/
│
├── skills/                           # 14 AI Engineering Skills
│   ├── android-cli/                  #   Core orchestrator
│   │   ├── SKILL.md                  #     Role definition & workflow
│   │   ├── references/               #     12 technical reference guides
│   │   ├── scripts/                  #     PowerShell utilities
│   │   ├── examples/                 #     Starter app templates
│   │   └── CHANGELOG.md              #     Version history
│   ├── android-ui-ux-design/         #   Material 3 + Compose design
│   ├── android-frontend-engineer/    #   MVVM + Navigation + DI
│   ├── android-testing-engineer/     #   Unit + UI + Compose testing
│   ├── app-performance-engineer/     #   Profiling + optimization
│   ├── backend-api-engineer/         #   NestJS + FastAPI + Docker
│   ├── database-offline-sync/        #   Room + offline-first + sync
│   ├── firebase-supabase-engineer/   #   BaaS integration
│   ├── android-security-engineer/    #   Auth + encryption + hardening
│   ├── android-security-lab-builder/ #   Security training labs
│   ├── devops-release-engineer/      #   CI/CD + signing + rollback
│   ├── ai-integration-engineer/      #   LLM APIs + on-device ML
│   ├── app-product-architect/        #   System design + API contracts
│   └── fullstack-web-engineer/       #   Next.js + React web companion
│
├── examples/                         # Working Example Applications
│   ├── fullstack-taskapp/            #   Android + NestJS + PostgreSQL + Redis
│   │   ├── android/                  #     Kotlin + Compose + Retrofit
│   │   ├── backend/                  #     NestJS + TypeORM + JWT + Swagger
│   │   └── docker/                   #     Docker Compose configuration
│   └── android-skilltest/            #   Minimal Android validation app
│
├── scripts/                          # Utility Scripts (PowerShell)
│   ├── install.ps1                   #   Skill installer (Claude/Gemini/Codex)
│   ├── sync-agents.ps1               #   Multi-agent skill synchronization
│   ├── inspect-device.ps1            #   ADB device/emulator inspection
│   ├── build-debug.ps1               #   APK build + install
│   ├── check-environment.ps1         #   Environment validation
│   ├── run-tests.ps1                 #   Test runner
│   └── validate-v3-skills.ps1        #   Skill structure validator
│
├── tests/                            # Test & Evaluation
│   └── skill-eval/                   #   Skill evaluation framework
│       ├── eval-cases.json           #     13 deterministic + 5 AI test cases
│       ├── run-eval.sh               #     Automated evaluation runner
│       └── README.md                 #     Evaluation documentation
│
├── .github/workflows/                # CI/CD Pipelines
│   ├── skills-validation.yml         #   14-skill structure validation
│   ├── docs-lint.yml                 #   Markdown lint & link check
│   ├── security-scan.yml             #   Secret & privacy scanning
│   ├── backend-tests.yml             #   NestJS + PostgreSQL integration
│   ├── android-build.yml             #   Gradle build + unit tests
│   ├── powershell-check.yml          #   Script syntax validation
│   └── release-gate.yml              #   Combined release readiness
│
├── docs/                             # Documentation
│   ├── ARCHITECTURE.md               #   Detailed architecture guide
│   └── banner.svg                    #   Repository banner
│
├── .env.example                      # Environment variable template
├── .gitignore                        # Git exclusion rules
├── VERSION                           # Semantic version (3.2.0)
├── CHANGELOG.md                      # Release history
├── LICENSE                           # MIT License
├── SECURITY.md                       # Security policy & reporting
├── CONTRIBUTING.md                   # Contribution guidelines
└── README.md                         # This file
```

---

## How Skills Work

```mermaid
flowchart TB
    User["Developer"] -->|"Asks AI to build a feature"| AI["AI Assistant<br/>(Claude Code)"]
    AI -->|"Loads relevant skill"| Skill["SKILL.md<br/><i>Role + Capabilities + Workflow</i>"]
    Skill -->|"References deep guides"| Refs["references/*.md<br/><i>Code patterns, APIs, best practices</i>"]
    Refs -->|"AI generates"| Code["Production-Ready Code<br/><i>Architecture patterns applied</i>"]
    Code -->|"Validated by"| Test["Testing Skill<br/><i>Unit + Integration + UI</i>"]
    Test -->|"Secured by"| Sec["Security Skill<br/><i>Audit + Hardening</i>"]
    Sec -->|"Shipped by"| Ship["DevOps Skill<br/><i>CI/CD + Release</i>"]

    style User fill:#3DDC84,stroke:#3DDC84,color:#000
    style AI fill:#7C4DFF,stroke:#7C4DFF,color:#fff
    style Skill fill:#00BCD4,stroke:#00BCD4,color:#fff
    style Refs fill:#3F51B5,stroke:#3F51B5,color:#fff
    style Code fill:#FF6D00,stroke:#FF6D00,color:#fff
    style Test fill:#E91E63,stroke:#E91E63,color:#fff
    style Sec fill:#FFD600,stroke:#FFD600,color:#000
    style Ship fill:#3DDC84,stroke:#3DDC84,color:#000
```

---

## Verified Test Results

The fullstack-taskapp example ships with passing tests:

| Suite | Tests | Status |
|-------|-------|--------|
| **Backend Integration** (Jest) | 13/13 | All passing |
| **Android Unit** (JUnit) | 3/3 | All passing |
| **Android Lint** | 0 errors | Clean |

**Verified CRUD operations** (Android UI → PostgreSQL):
Register → Login → Create Task → List Tasks → Toggle Status → Delete Task

---

## Running Tests

### Skill Evaluation (no dependencies needed)
```bash
bash tests/skill-eval/run-eval.sh
```

### Backend Integration Tests
```bash
# Requires Docker running
cd examples/fullstack-taskapp/docker
docker compose up -d postgres

cd ../backend
npm install && npm run build

# Set test env vars
export DATABASE_URL=postgresql://demouser:yourpassword@localhost:5433/demoapp
export JWT_SECRET=your-test-secret

# Run tests
npx jest --config jest.config.js --forceExit --verbose
```

### Android Unit Tests
```bash
cd examples/fullstack-taskapp/android
./gradlew testDebugUnitTest
```

### Release Validation (all checks)
```bash
bash scripts/release-check.sh
```

---

## Installer Examples

```powershell
# Preview what will be installed (dry run)
./scripts/install.ps1 -WhatIf

# Install skills to Claude Code
./scripts/install.ps1

# Install to all AI assistants (Claude + Gemini + Codex)
./scripts/install.ps1 -Target All

# Upgrade existing skills (backs up first, then overwrites)
./scripts/install.ps1 -Action Upgrade -Force

# Back up current skills without changing them
./scripts/install.ps1 -Action Backup

# Uninstall (backs up first, then removes)
./scripts/install.ps1 -Action Uninstall
```

---

## Supported Environments

| Component | Minimum | Tested With |
|-----------|---------|-------------|
| **OS** | Windows 10, macOS 12, Ubuntu 20.04 | Windows 11 Pro |
| **Android SDK** | API 33 (compileSdk 35) | API 36 emulator |
| **Kotlin** | 2.0+ | 2.0.21 |
| **Gradle** | 8.0+ | 9.1.0 |
| **Node.js** | 18+ | 22.x |
| **Docker** | 20.10+ | Latest |
| **PostgreSQL** | 14+ | 16-alpine |
| **AI Assistant** | Claude Code, Gemini CLI, or Codex | Claude Code |

---

## Continuous Integration

Every push and pull request triggers these automated checks:

| Workflow | What It Checks |
|----------|---------------|
| **Skill Validation** | 14 skills present, SKILL.md + references/ structure, no empty files |
| **Docs Lint** | Markdown formatting, internal link integrity |
| **Security Scan** | Hardcoded credentials, API keys, user paths, personal data, npm audit |
| **Backend Tests** | TypeScript compilation, 13 Jest integration tests against PostgreSQL |
| **Android Build** | Gradle build, 3 unit tests, lint check for both example apps |
| **PowerShell Check** | Script syntax validation, installer dry-run |
| **Release Gate** | All of the above as a combined release readiness check |

---

## Release History

| Version | Date | Highlights |
|---------|------|------------|
| **3.2.0** | 2026-10-23 | CI/CD, skill evaluation framework, installer upgrade/backup/uninstall, security hardening |
| **3.1.0** | 2026-10-22 | Initial public release — 14 skills, fullstack TaskApp, documentation |

See [CHANGELOG.md](CHANGELOG.md) for full details.

---

## Known Limitations

- **Android instrumented tests** are not included (no Compose UI tests in `androidTest/`)
- **npm audit** reports 6 vulnerabilities in transitive dependencies (uuid, typeorm) — none exploitable in this demo context
- **CORS** defaults to `origin: *` for development — restrict via `CORS_ORIGIN` env var in production
- **Token storage** in the Android app is in-memory only — use `EncryptedSharedPreferences` for production
- **AI behavior evaluations** require manual execution with a specific AI model — results vary by model and version

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on submitting issues, features, and pull requests.

## Security

See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.

## License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center">
  <sub>Built with Android + Kotlin + Jetpack Compose + NestJS + PostgreSQL + Docker</sub><br/>
  <sub>CI/CD powered by GitHub Actions</sub>
</p>
