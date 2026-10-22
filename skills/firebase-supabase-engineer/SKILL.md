---
name: firebase-supabase-engineer
description: Firebase and Supabase integration for Android apps including authentication, Firestore, Realtime Database, Cloud Storage, Cloud Functions, Supabase PostgreSQL, and real-time subscriptions
metadata:
  author: Custom
  keywords:
  - firebase
  - supabase
  - firestore
  - authentication
  - cloud-functions
  - realtime
  - storage
  - analytics
---

# Firebase & Supabase Engineering Skill

## Trigger Conditions

Activate this skill when the task involves any of:

- Setting up Firebase or Supabase in an Android/Kotlin project
- Implementing authentication (email/password, OAuth, phone, anonymous, MFA)
- Cloud database operations (Firestore, Realtime Database, Supabase PostgreSQL)
- File storage (Firebase Storage, Supabase Storage)
- Push notifications (FCM setup, notification channels, topic messaging)
- Analytics and crash reporting (Firebase Analytics, Crashlytics)
- Serverless functions (Cloud Functions, Supabase Edge Functions)
- Real-time data synchronization or subscriptions
- Security rules (Firestore rules, Supabase RLS policies)
- Remote Config, App Check, or A/B testing setup
- Backend-as-a-Service architecture decisions

## Capabilities

### Firebase

| Service | Description |
|---|---|
| **Firebase Auth** | Email/password, Google Sign-In, phone, anonymous, Apple, custom tokens, multi-factor authentication |
| **Cloud Firestore** | NoSQL document database with real-time sync, offline persistence, compound queries |
| **Realtime Database** | JSON tree database with low-latency sync, presence system, fan-out data model |
| **Cloud Storage** | File uploads/downloads with security rules, resumable uploads, metadata management |
| **Cloud Functions** | Node.js/TypeScript serverless functions triggered by HTTP, Firestore, Auth, Storage, Pub/Sub, scheduled |
| **Cloud Messaging (FCM)** | Push notifications, topic messaging, data messages, notification channels |
| **Analytics** | Event logging, user properties, audience segmentation, BigQuery export |
| **Crashlytics** | Crash reporting, non-fatal error logging, custom keys, breadcrumbs |
| **Remote Config** | Server-side feature flags, A/B testing, gradual rollouts |
| **App Check** | App attestation to protect backend resources from abuse |

### Supabase

| Service | Description |
|---|---|
| **Supabase Auth** | Email/password, OAuth providers, magic links, phone OTP, session management |
| **PostgreSQL** | Full Postgres with PostgREST API, views, functions, triggers, extensions |
| **Realtime** | WebSocket subscriptions for INSERT/UPDATE/DELETE on any table |
| **Storage** | S3-compatible object storage with RLS, signed URLs, image transformations |
| **Edge Functions** | Deno-based serverless functions deployed globally |

## Workflow

1. **Choose Platform** - Evaluate Firebase vs Supabase based on project requirements
2. **Configure Project** - Create project in console, download config files, add SDKs
3. **Integrate SDK** - Add dependencies to build.gradle.kts, initialize in Application class
4. **Implement Features** - Auth flows, database operations, storage, functions
5. **Secure Rules** - Write Firestore security rules or Supabase RLS policies
6. **Test** - Use Firebase Emulator Suite or Supabase local dev for testing
7. **Monitor** - Set up Analytics, Crashlytics, performance monitoring

## Firebase vs Supabase Decision Guide

| Factor | Firebase | Supabase |
|---|---|---|
| **Database Model** | NoSQL (document) | Relational (PostgreSQL) |
| **Query Complexity** | Limited joins, denormalized data | Full SQL, joins, views, CTEs |
| **Real-time** | Built-in snapshot listeners | WebSocket channel subscriptions |
| **Auth Providers** | 10+ built-in providers | OAuth, email, phone, magic link |
| **Offline Support** | Built-in persistence | Manual caching required |
| **Pricing** | Pay-per-read/write, generous free tier | Predictable per-project pricing |
| **Vendor Lock-in** | High (proprietary) | Low (open-source, self-hostable) |
| **Scaling** | Automatic, managed | Managed or self-hosted |
| **Functions Runtime** | Node.js 18/20 | Deno (Edge Functions) |
| **Best For** | Rapid prototyping, mobile-first, real-time apps | Complex data models, SQL familiarity, open-source preference |

**Choose Firebase when:** You need deep Android integration, built-in offline support, FCM push notifications, Crashlytics, or Remote Config. Best for apps with simple data models and heavy real-time requirements.

**Choose Supabase when:** Your data model is relational, you need complex queries/joins, you want SQL access, you prefer open-source, or you need predictable pricing. Best for apps with structured data and existing PostgreSQL knowledge.

## SDK Setup Quick Reference

### Firebase (build.gradle.kts - app level)

```kotlin
plugins {
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-config-ktx")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
}
```

### Supabase (build.gradle.kts - app level)

```kotlin
dependencies {
    implementation(platform("io.github.jan-tennert.supabase:bom:3.1.1"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.ktor:ktor-client-android:3.1.1")
}
```

## Reference Files

- `references/firebase-auth.md` - Authentication patterns and Compose integration
- `references/firestore.md` - Firestore data model, queries, security rules
- `references/supabase-integration.md` - Supabase-kt SDK, PostgreSQL, Realtime, RLS
- `references/cloud-storage.md` - Firebase Storage and Supabase Storage operations
- `references/cloud-functions.md` - Cloud Functions and Edge Functions
- `references/push-analytics.md` - FCM, Analytics, Crashlytics
- `references/security-rules.md` - Firestore rules and Supabase RLS policies
