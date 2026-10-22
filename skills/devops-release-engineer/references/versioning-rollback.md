# Versioning & Rollback

## Semantic Versioning for Android Apps

Follow `MAJOR.MINOR.PATCH` convention:

- **MAJOR**: Breaking changes, major UI redesign, database migration requiring fresh install
- **MINOR**: New features, non-breaking API changes, significant improvements
- **PATCH**: Bug fixes, performance improvements, small UI tweaks

Example progression: `1.0.0` -> `1.0.1` (bugfix) -> `1.1.0` (new feature) -> `2.0.0` (redesign)

## versionCode Strategy

The `versionCode` is an integer that must strictly increase with each release uploaded to Play Console.

### Date-Based Strategy

Format: `YYMMDDHH` -- encodes the build date, guaranteeing uniqueness:

```kotlin
// Generates versionCode like 25011510 for 2025-01-15 10:xx
val versionCode = java.time.LocalDate.now().let { d ->
    (d.year % 100) * 1_000_000 + d.monthValue * 10_000 + d.dayOfMonth * 100 +
    (System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull()?.rem(100) ?: 0)
}
```

Pros: Sortable, encodes date information, no external state needed.
Cons: Limited to 100 builds per day; two builds in the same hour on different branches can collide without the run number suffix.

### Sequential Strategy (CI Build Number)

Use the CI build number directly:

```kotlin
val versionCode = System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull() ?: 1
```

Pros: Simple, always increases, no collisions.
Cons: Tied to CI system; migrating CI resets the counter (set an offset).

### Multi-Flavor Strategy

When using product flavors, offset the versionCode per flavor to avoid Play Console conflicts:

```kotlin
productFlavors {
    create("free") {
        versionCode = baseVersionCode
    }
    create("premium") {
        versionCode = baseVersionCode + 1_000_000
    }
}
```

## Changelog Generation

### From Conventional Commits

Use conventional commit format: `type(scope): description`

```bash
# Generate changelog since last tag
git log $(git describe --tags --abbrev=0)..HEAD --pretty=format:"%s" --no-merges | \
while IFS= read -r line; do
    case "$line" in
        feat*) echo "### New Features"; echo "- ${line#feat*: }" ;;
        fix*)  echo "### Bug Fixes"; echo "- ${line#fix*: }" ;;
        perf*) echo "### Performance"; echo "- ${line#perf*: }" ;;
    esac
done | sort | uniq
```

### Automated with a tool

```bash
# Using git-cliff
git cliff --unreleased --output CHANGELOG.md

# git-cliff.toml configuration
[changelog]
header = "# Changelog\n"
body = """
{% for group, commits in commits | group_by(attribute="group") %}
### {{ group }}
{% for commit in commits %}
- {{ commit.message | upper_first }} ({{ commit.id | truncate(length=7, end="") }})
{% endfor %}
{% endfor %}
"""
trim = true

[git]
conventional_commits = true
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
    { message = "^doc", group = "Documentation" },
]
```

## Git Tagging

### Creating release tags

```bash
# Tag the release commit
git tag -a v2.4.1 -m "Release 2.4.1: Fix payment timeout, add dark mode"

# Push tags
git push origin v2.4.1

# List recent tags
git tag --sort=-creatordate | head -10
```

### Tag naming convention

- Release: `v2.4.1`
- Release candidate: `v2.4.1-rc.1`
- Beta: `v2.4.1-beta.1`
- Hotfix: `v2.4.2` (patch bump from the release being fixed)

## Release Branches

### Git flow for releases

```
main          ─────●──────────────●──────── (production releases)
                  /                \
release/2.4  ───●───●───●──────────● (stabilization)
                /       \
develop     ──●─────────●────────────── (ongoing development)
```

### Creating a release branch

```bash
# Branch from develop when feature-complete
git checkout develop
git checkout -b release/2.4.0

# Stabilize: only bug fixes on this branch
git commit -m "fix: resolve payment timeout on slow networks"

# When ready, merge to main and tag
git checkout main
git merge --no-ff release/2.4.0
git tag -a v2.4.0 -m "Release 2.4.0"

# Merge back to develop
git checkout develop
git merge --no-ff release/2.4.0
```

### Hotfix Workflow

```bash
# Branch from main (production)
git checkout main
git checkout -b hotfix/2.4.1

# Fix the critical bug
git commit -m "fix: crash on null payment response"

# Merge to main and tag
git checkout main
git merge --no-ff hotfix/2.4.1
git tag -a v2.4.1 -m "Hotfix 2.4.1: Fix payment crash"

# Merge to develop
git checkout develop
git merge --no-ff hotfix/2.4.1
```

## Play Console Staged Rollouts

### Percentage-Based Rollout

| Stage | Percentage | Duration | Gate Criteria |
|-------|-----------|----------|---------------|
| 1 | 1% | 24 hours | No new crash clusters, crash-free > 99.5% |
| 2 | 5% | 24 hours | Crash-free stable, no P0/P1 user reports |
| 3 | 20% | 24-48 hours | Metrics stable, no rating drops |
| 4 | 50% | 24 hours | Final check before full rollout |
| 5 | 100% | -- | Full release |

### Managing rollouts via Play Console API

```bash
# Using the Google Play Developer API via a script
# Promote from internal to production at 5%
curl -X PATCH \
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.example.app/edits/${EDIT_ID}/tracks/production" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "track": "production",
        "releases": [{
            "versionCodes": ["250"],
            "userFraction": 0.05,
            "status": "inProgress"
        }]
    }'
```

### Monitoring Rollout Metrics

During staged rollout, monitor in Play Console > Release > Release dashboard:

- **Crash rate** by release version vs previous version
- **ANR rate** comparison
- **User ratings** for the new version
- **Uninstall rate** spike detection
- **Device-specific issues** in the Devices section

## Rollback Procedures

### Re-Release Previous Version

If a critical issue is found during rollout:

1. **Halt the rollout**: In Play Console, click "Halt rollout" on the problematic release
2. **Upload previous AAB**: Re-upload the last known good AAB with a new (higher) versionCode
3. **Full rollout**: Release the reverted version at 100%

```bash
# Bump versionCode and rebuild the last good version
git checkout v2.4.0  # Last good tag
# Increment versionCode in build.gradle.kts (must be higher than the bad release)
./gradlew bundleRelease
# Upload to Play Console
```

### Server-Side Feature Flags

Use Firebase Remote Config to disable features without a new release:

```kotlin
val remoteConfig = Firebase.remoteConfig
remoteConfig.setDefaultsAsync(mapOf(
    "new_checkout_enabled" to false,
    "video_player_v2" to false,
))

// Fetch and activate
remoteConfig.fetchAndActivate().addOnCompleteListener {
    val newCheckoutEnabled = remoteConfig.getBoolean("new_checkout_enabled")
    if (newCheckoutEnabled) {
        showNewCheckout()
    } else {
        showLegacyCheckout()
    }
}
```

Toggle in Firebase Console without deploying: set `new_checkout_enabled` to `false` to instantly revert the feature for all users.

### Rollback Decision Matrix

| Severity | Crash Rate Impact | Action | Timeline |
|----------|------------------|--------|----------|
| P0 - App unusable | > 5% crash rate | Immediate halt + rollback | < 1 hour |
| P1 - Major feature broken | 1-5% crash rate | Halt rollout, hotfix or rollback within 4 hours | < 4 hours |
| P2 - Minor feature broken | < 1% crash rate | Continue rollout paused, hotfix in next release | < 24 hours |
| P3 - Cosmetic | No crash impact | Note for next release | Next sprint |

## Post-Mortem Template

After every P0 or P1 incident, complete within 48 hours:

```markdown
## Incident Post-Mortem: [Title]

**Date**: YYYY-MM-DD
**Duration**: X hours Y minutes
**Severity**: P0 / P1
**Author**: [Name]

### Summary
One-paragraph description of what happened.

### Timeline (all times UTC)
- HH:MM - First alert / detection
- HH:MM - Investigation started
- HH:MM - Root cause identified
- HH:MM - Mitigation applied (rollback / hotfix / flag toggle)
- HH:MM - Verified resolution
- HH:MM - Incident closed

### Impact
- Users affected: N (X% of DAU)
- Revenue impact: estimated $X
- Crash-free rate drop: from 99.X% to 99.Y%

### Root Cause
Technical explanation of what caused the incident.

### What Went Well
- Detection was fast (alert fired within X minutes)
- Rollback procedure worked as documented

### What Went Wrong
- Missing test coverage for edge case X
- Monitoring did not alert on metric Y

### Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| Add test for edge case X | @dev | YYYY-MM-DD | TODO |
| Add alerting for metric Y | @devops | YYYY-MM-DD | TODO |
| Update rollback runbook | @lead | YYYY-MM-DD | TODO |

### Lessons Learned
Bullet points of key takeaways for the team.
```
