# Firebase Deployment

## Firebase App Distribution

### Gradle Plugin Setup

Add the plugin to your project:

```kotlin
// build.gradle.kts (project level)
plugins {
    id("com.google.firebase.appdistribution") version "5.1.0" apply false
}

// app/build.gradle.kts
plugins {
    id("com.google.firebase.appdistribution")
}

android {
    buildTypes {
        debug {
            firebaseAppDistribution {
                artifactType = "APK"
                groups = "internal-testers"
                releaseNotes = "Debug build from CI"
            }
        }
        create("staging") {
            firebaseAppDistribution {
                artifactType = "APK"
                groups = "qa-team, beta-testers"
                releaseNotesFile = "release-notes.txt"
            }
        }
    }
}
```

### Tester Groups

Manage tester groups in Firebase Console > App Distribution > Testers & Groups:

| Group | Purpose | Members |
|-------|---------|---------|
| `internal-testers` | Dev team, every build | developers@example.com |
| `qa-team` | QA engineers, staging builds | qa@example.com |
| `beta-testers` | External beta, release candidates | invited beta users |
| `stakeholders` | Product/design review | product@example.com |

### Distributing from Command Line

```bash
# Using Firebase CLI
firebase appdistribution:distribute app-debug.apk \
    --app 1:123456789:android:abcdef \
    --groups "internal-testers" \
    --release-notes "Build $(git rev-parse --short HEAD): $(git log -1 --pretty=%B)"

# Using Gradle task
./gradlew assembleDebug appDistributionUploadDebug
```

### Release Notes from Git

Generate release notes from recent commits:

```bash
# release-notes.txt generation script
echo "Changes since last release:" > release-notes.txt
git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD \
    --pretty=format:"- %s" --no-merges >> release-notes.txt
```

## Firebase CI Token Authentication

### Service Account (recommended for CI)

1. Go to Google Cloud Console > IAM & Admin > Service Accounts
2. Create a service account with Firebase App Distribution Admin role
3. Generate a JSON key file
4. Store the JSON content as a CI secret

```yaml
# GitHub Actions
- name: Distribute to Firebase
  run: ./gradlew assembleStagingDebug appDistributionUploadStagingDebug
  env:
    GOOGLE_APPLICATION_CREDENTIALS: ${{ runner.temp }}/firebase-sa.json

- name: Write service account file
  run: echo '${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}' > ${{ runner.temp }}/firebase-sa.json
```

### Firebase CLI Token (legacy)

```bash
# Generate token locally (one-time)
firebase login:ci
# Outputs a refresh token; store as FIREBASE_TOKEN secret

# Use in CI
firebase appdistribution:distribute app.apk \
    --app $FIREBASE_APP_ID \
    --token "$FIREBASE_TOKEN" \
    --groups "qa-team"
```

## Firebase Hosting

### Deploy web dashboards or landing pages

```bash
# Initialize Firebase Hosting
firebase init hosting

# firebase.json
{
  "hosting": {
    "public": "dist",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      }
    ]
  }
}
```

### Preview channels for PRs

```yaml
# .github/workflows/firebase-hosting-preview.yml
name: Deploy Preview
on: pull_request

jobs:
  preview:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: your-project-id
          expires: 7d  # Preview expires after 7 days
```

## Cloud Functions Deployment

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:processPayment

# Deploy with environment configuration
firebase functions:config:set stripe.key="sk_live_xxx"
firebase deploy --only functions
```

### GitHub Actions for Cloud Functions

```yaml
- name: Deploy Cloud Functions
  run: |
    cd functions
    npm ci
    npx firebase deploy --only functions --project ${{ vars.FIREBASE_PROJECT_ID }}
  env:
    GOOGLE_APPLICATION_CREDENTIALS: ${{ runner.temp }}/firebase-sa.json
```

## Firestore Security Rules

### Deploy rules

```bash
firebase deploy --only firestore:rules
```

### Test rules before deploying

```bash
# Install emulator
firebase emulators:start --only firestore

# Run security rules tests
npm test -- --testPathPattern=firestore.rules.test
```

### Rules CI workflow

```yaml
- name: Test Firestore rules
  run: |
    npm install -g firebase-tools
    firebase emulators:exec --only firestore "npm test" \
        --project ${{ vars.FIREBASE_PROJECT_ID }}
```

## Pre-Release Testing Workflow

A complete pre-release flow from code to beta:

```yaml
name: Pre-Release

on:
  push:
    branches: [release/*]

jobs:
  build-and-distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - uses: gradle/actions/setup-gradle@v4

      - name: Run full test suite
        run: ./gradlew testStagingUnitTest lintStaging --no-daemon

      - name: Generate release notes
        run: |
          echo "Release candidate from branch ${GITHUB_REF_NAME}" > release-notes.txt
          echo "" >> release-notes.txt
          git log --pretty=format:"- %s (%an)" $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --no-merges >> release-notes.txt

      - name: Write service account
        run: echo '${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}' > ${{ runner.temp }}/firebase-sa.json

      - name: Build and distribute to QA
        run: ./gradlew assembleStagingRelease appDistributionUploadStagingRelease --no-daemon
        env:
          GOOGLE_APPLICATION_CREDENTIALS: ${{ runner.temp }}/firebase-sa.json
          KEYSTORE_FILE: app/release-keystore.jks
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Notify team
        uses: slackapi/slack-github-action@v2.0.0
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": "New staging build distributed to QA: ${{ github.ref_name }}"
            }
```

## Feedback Collection

Firebase App Distribution includes built-in feedback:

1. **In-app feedback**: Testers shake the device to report issues with screenshots
2. **Tester web clips**: Install the Firebase App Tester app for iOS/Android
3. **Release notes**: Testers see release notes before installing
4. **Email notifications**: Automatic email when new builds are available

For structured feedback, combine with:
- Firebase Crashlytics for automated crash reporting
- Custom in-app feedback forms that submit to Firestore
- Google Forms linked from release notes for structured testing checklists
