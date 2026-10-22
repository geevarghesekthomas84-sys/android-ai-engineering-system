---
name: devops-release-engineer
description: DevOps and release engineering for Android and backend with Gradle builds, signing, GitHub Actions CI/CD, Docker, Firebase/Play Console deployment, and monitoring
metadata:
  author: Custom
  keywords:
  - devops
  - ci-cd
  - github-actions
  - gradle
  - docker
  - signing
  - play-console
  - release
  - monitoring
---

# DevOps & Release Engineering Skill

## Trigger Conditions

Activate this skill when the task involves any of:

- **CI/CD setup**: Creating or modifying GitHub Actions workflows, build pipelines, automated testing gates, branch protection rules, or merge strategies
- **Release builds**: Configuring Gradle build types, product flavors, R8/ProGuard shrinking, APK splits, AAB generation, or build optimization
- **Signing configuration**: Keystore management, upload keys, Play App Signing enrollment, CI/CD signing secrets, or signature verification
- **Deployment**: Firebase App Distribution, Play Console uploads, Docker container deployment, staging/production promotion, or rollout management
- **Monitoring & observability**: Crashlytics setup, performance monitoring, error alerting, SLI/SLO definition, or incident response
- **Versioning & rollback**: Version code/name strategy, changelog generation, Git tagging, release branches, staged rollouts, or rollback procedures
- **Infrastructure**: Docker compose services, reverse proxy configuration, database containers, health checks, or resource management

## Capabilities

### Android Build & Release
- Gradle release build configuration with debug/release/staging build types
- Product flavor management for multi-brand or environment-specific builds
- APK and AAB (Android App Bundle) generation with optimized output
- R8 code shrinking, obfuscation, and resource shrinking
- APK splits by ABI and screen density for reduced download size
- Version management with automated versionCode increment and semantic versionName
- Build cache and configuration cache for faster CI builds

### Signing & Security
- Keystore creation and secure storage practices
- Environment variable-based signing configuration for CI/CD
- Google Play App Signing enrollment and upload key management
- Key rotation procedures and signing report verification
- APK/AAB signature verification with apksigner and bundletool

### CI/CD with GitHub Actions
- Complete Android CI workflows: build, test, lint, instrumented tests
- Gradle caching strategies for faster pipeline execution
- Matrix builds across multiple API levels and device configurations
- Branch-based workflows: PR checks, develop builds, release tag deployments
- Artifact management: APK/AAB upload, test reports, lint results
- Status checks and branch protection rule configuration

### Docker & Backend Deployment
- Multi-stage Dockerfiles for NestJS and FastAPI backends
- Docker Compose service orchestration (app, database, cache, reverse proxy)
- Environment configuration with .env files and Docker secrets
- Zero-downtime deployment with rolling updates
- Health check configuration and container resource limits
- Production compose overrides and logging strategies

### Firebase & Distribution
- Firebase App Distribution via Gradle plugin with tester groups
- Firebase Hosting deployment for web dashboards and landing pages
- Cloud Functions deployment and Firestore security rules
- Beta distribution channels with release notes and feedback collection
- CI token-based authentication for automated deployments

### Monitoring & Observability
- Crashlytics integration with custom keys, breadcrumbs, and mapping file upload
- Firebase Performance Monitoring with custom traces and HTTP metrics
- Structured logging and error alerting configuration
- SLI/SLO definition for mobile and backend services
- Incident response procedures and rollback decision trees

### Versioning & Rollback
- Semantic versioning strategy for Android apps
- Automated changelog generation from conventional commits
- Git tagging and release branch management
- Play Console staged rollouts with percentage-based progression
- Rollback procedures including re-release and feature flag killswitches
- Post-mortem templates for release incidents

## CRITICAL RULES

1. **Never publish signing keys, API keys, or secrets** to version control, logs, or artifacts. Always use encrypted secrets, environment variables, or secret managers.
2. **Never rotate production signing keys** without explicit approval and a documented rollback plan. Key rotation affects all existing users.
3. **Never delete production data**, including Firestore collections, Cloud Storage buckets, or database tables, without explicit approval and a verified backup.
4. **Never deploy to production** without explicit approval. Always deploy to staging first, verify, then promote.
5. **Never bypass quality gates**. If tests fail, lint errors exist, or signing verification fails, stop and report. Do not use `--continue` or `--stacktrace` to push through broken builds.
6. **Never hardcode environment-specific values**. Use build config fields, environment variables, or remote config.
7. **Always verify signatures** after signing. An unsigned or incorrectly signed release binary is a blocked release.
8. **Always preserve mapping files** (R8/ProGuard) for every release build. Without them, crash reports are unreadable.

## Workflow

The standard release engineering workflow follows these phases:

### Phase 1: Build Configuration
1. Configure build variants (debug, staging, release) with appropriate build config fields
2. Set up product flavors if multi-brand or environment-specific builds are needed
3. Configure R8 shrinking with appropriate keep rules
4. Set up resource shrinking and APK optimization (splits or AAB)
5. Verify builds complete successfully for all variants

### Phase 2: Signing Setup
1. Create or locate the release keystore
2. Configure signing in `build.gradle.kts` using environment variables (never hardcoded paths or passwords)
3. Enroll in Google Play App Signing if not already done
4. Verify signing with `signingReport` and `apksigner verify`
5. Store signing credentials in CI/CD secret storage (GitHub Secrets, etc.)

### Phase 3: CI Pipeline
1. Create GitHub Actions workflow for PR checks (build, test, lint)
2. Add instrumented test jobs with emulator runner
3. Configure Gradle caching for build speed
4. Set up artifact upload for APK/AAB and test reports
5. Configure branch protection rules requiring status checks

### Phase 4: Quality Gates
1. Unit test pass rate threshold (100% pass required)
2. Lint error threshold (zero errors, configurable warning limit)
3. Code coverage minimum (configurable, recommend 70%+)
4. APK size budget monitoring
5. Dependency vulnerability scanning

### Phase 5: Staging Deployment
1. Deploy to Firebase App Distribution for internal/beta testers
2. Deploy backend to staging Docker environment
3. Run smoke tests against staging
4. Collect tester feedback via Firebase channels

### Phase 6: Production Release
1. Obtain explicit approval for production deployment
2. Tag the release commit with semantic version
3. Build and sign the release AAB
4. Upload to Play Console as staged rollout (start at 1-5%)
5. Deploy backend with zero-downtime rolling update
6. Monitor crash rate and ANR rate for 24-48 hours
7. Increase rollout percentage progressively (5% -> 20% -> 50% -> 100%)

### Phase 7: Post-Release
1. Verify Crashlytics mapping file upload for deobfuscation
2. Monitor crash-free rate against SLO (target: 99.5%+)
3. Watch performance metrics for regression
4. Generate changelog and update release notes
5. Archive build artifacts and mapping files

## Reference Documents

- `references/gradle-release.md` - Gradle build configuration for release engineering
- `references/signing-security.md` - Signing security practices and keystore management
- `references/github-actions.md` - GitHub Actions CI/CD workflows for Android
- `references/docker-backend.md` - Docker backend deployment configuration
- `references/firebase-deployment.md` - Firebase App Distribution and deployment
- `references/monitoring.md` - Production monitoring and observability
- `references/versioning-rollback.md` - Versioning strategy and rollback procedures
