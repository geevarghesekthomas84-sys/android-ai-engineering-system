# Android AI Engineering System v3.1

A comprehensive AI-assisted engineering skill set for Android development, covering the full stack from UI design through backend APIs, security, DevOps, and AI integration.

## Overview

This system provides **14 specialized AI engineering skills** that guide Claude Code (or compatible AI assistants) through professional Android development workflows. Each skill is a self-contained reference with architecture patterns, code examples, and best practices.

### Skills

| # | Skill | Focus |
|---|-------|-------|
| 1 | **android-cli** | Core orchestrator — ADB, emulator, Gradle, device management |
| 2 | **android-ui-ux-design** | Material 3, Compose layouts, accessibility, theming |
| 3 | **android-frontend-engineer** | MVVM, state management, navigation, dependency injection |
| 4 | **android-testing-engineer** | Unit tests, Espresso, UI Automator, Compose testing |
| 5 | **app-performance-engineer** | Profiling, memory, startup optimization, benchmarks |
| 6 | **backend-api-engineer** | NestJS, FastAPI, authentication, REST/GraphQL APIs |
| 7 | **database-offline-sync** | Room, offline-first, sync strategies, migrations |
| 8 | **firebase-supabase-engineer** | Firebase, Supabase, cloud functions, real-time data |
| 9 | **android-security-engineer** | Secure storage, auth, network security, code obfuscation |
| 10 | **android-security-lab-builder** | Security labs for crypto, storage, network vulnerabilities |
| 11 | **devops-release-engineer** | CI/CD, versioning, release management, rollback |
| 12 | **ai-integration-engineer** | LLM APIs, on-device ML, RAG, prompt engineering |
| 13 | **app-product-architect** | System design, API contracts, data modeling, scalability |
| 14 | **fullstack-web-engineer** | Next.js, React, full-stack web companion to mobile |

### Example Applications

- **fullstack-taskapp** — A complete Android + NestJS + PostgreSQL + Redis task management app demonstrating end-to-end integration (Kotlin/Compose, Retrofit, JWT auth, Docker)
- **android-skilltest** — A minimal Android app used to validate skill-driven development workflows

## Getting Started

### Prerequisites

- [Android Studio](https://developer.android.com/studio) with SDK 35+
- [Node.js](https://nodejs.org/) 20+ (for backend examples)
- [Docker](https://www.docker.com/) (for PostgreSQL/Redis)
- [Claude Code](https://claude.com/claude-code) or compatible AI assistant

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/geevarghesekthomas84-sys/android-ai-engineering-system.git
   cd android-ai-engineering-system
   ```

2. Copy skills to your AI assistant's skill directory:
   ```bash
   # For Claude Code
   cp -r skills/* ~/.claude/skills/

   # Or use the installation script
   ./scripts/install.ps1 -WhatIf   # Preview changes
   ./scripts/install.ps1            # Install
   ```

3. Set up the fullstack example (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your database password and JWT secret

   cd examples/fullstack-taskapp/docker
   docker compose up -d

   cd ../backend
   npm install
   npm run build
   node dist/main.js
   ```

## Project Structure

```
android-ai-engineering-system/
├── skills/                    # 14 AI engineering skills
│   ├── android-cli/           #   Core orchestrator (scripts, references, examples)
│   ├── android-ui-ux-design/  #   UI/UX design patterns
│   ├── android-frontend-engineer/
│   ├── android-testing-engineer/
│   ├── app-performance-engineer/
│   ├── backend-api-engineer/
│   ├── database-offline-sync/
│   ├── firebase-supabase-engineer/
│   ├── android-security-engineer/
│   ├── android-security-lab-builder/
│   ├── devops-release-engineer/
│   ├── ai-integration-engineer/
│   ├── app-product-architect/
│   └── fullstack-web-engineer/
├── examples/                  # Working example applications
│   ├── fullstack-taskapp/     #   Android + NestJS + PostgreSQL + Redis
│   └── android-skilltest/     #   Minimal Android validation app
├── scripts/                   # Utility scripts
│   ├── install.ps1            #   Skill installation script
│   ├── sync-agents.ps1        #   Multi-agent synchronization
│   ├── inspect-device.ps1     #   ADB device inspection
│   ├── build-and-install.ps1  #   APK build + install
│   ├── capture-screenshot.ps1 #   Emulator screenshot capture
│   └── run-lint-fix.ps1       #   Lint and auto-fix
├── docs/                      # Architecture documentation
│   └── ARCHITECTURE.md
├── .env.example               # Environment variable template
├── .gitignore
├── LICENSE                    # MIT License
├── SECURITY.md                # Security policy
├── CONTRIBUTING.md            # Contribution guidelines
└── README.md                  # This file
```

## Architecture

The system follows a modular skill-based architecture. Each skill is independent and can be used alone or composed with others:

```
┌─────────────────────────────────────────────────────┐
│                  AI Assistant (Claude Code)           │
│  Loads skills from ~/.claude/skills/                 │
└──────────┬──────────────────────────────┬────────────┘
           │                              │
    ┌──────▼──────┐                ┌──────▼──────┐
    │  Frontend    │                │  Backend    │
    │  Skills      │                │  Skills     │
    │ ─────────── │                │ ─────────── │
    │ ui-ux-design │                │ backend-api │
    │ frontend-eng │                │ firebase    │
    │ testing-eng  │                │ database    │
    │ performance  │                │ fullstack   │
    └──────┬──────┘                └──────┬──────┘
           │                              │
    ┌──────▼──────────────────────────────▼──────┐
    │              Cross-cutting Skills           │
    │ ─────────────────────────────────────────── │
    │ security-engineer  │  devops-release        │
    │ security-lab       │  ai-integration        │
    │ product-architect  │  android-cli (core)    │
    └────────────────────────────────────────────┘
```

## Fullstack TaskApp Architecture

The included example demonstrates real end-to-end integration:

```
┌──────────────────────┐
│  Android App          │
│  Kotlin + Compose     │
│  Retrofit + OkHttp    │
│  MVVM (ViewModel)     │
└──────┬───────────────┘
       │ HTTP (10.0.2.2:3000)
┌──────▼───────────────┐
│  NestJS Backend       │
│  TypeORM + JWT        │
│  bcrypt + Swagger     │
└──────┬───────────────┘
       │
┌──────▼───────────────┐  ┌──────────────────┐
│  PostgreSQL 16        │  │  Redis 7          │
│  (Docker)             │  │  (Docker)         │
│  users + tasks        │  │  session cache    │
└──────────────────────┘  └──────────────────┘
```

## License

[MIT](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
