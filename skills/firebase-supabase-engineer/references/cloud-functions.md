# Serverless Functions

## Firebase Cloud Functions

### Setup

```bash
npm install -g firebase-tools
firebase login
firebase init functions  # Choose TypeScript
```

```json
// functions/package.json
{
  "engines": { "node": "20" },
  "dependencies": {
    "firebase-admin": "^12.7.0",
    "firebase-functions": "^6.2.0"
  }
}
```

### HTTP Triggers

```typescript
// functions/src/index.ts
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

// Public HTTP endpoint
export const healthCheck = onRequest((req, res) => {
    res.json({ status: "ok", timestamp: Date.now() });
});

// Authenticated HTTP endpoint
export const getUserProfile = onRequest(async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
        res.status(401).json({ error: "Unauthorized" });
        return;
    }

    try {
        const token = authHeader.split("Bearer ")[1];
        const decoded = await admin.auth().verifyIdToken(token);
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(decoded.uid)
            .get();

        res.json(userDoc.data());
    } catch (error) {
        res.status(403).json({ error: "Invalid token" });
    }
});
```

### Callable Functions (type-safe client-server)

```typescript
import { onCall, HttpsError } from "firebase-functions/v2/https";

interface CreatePostRequest {
    title: string;
    content: string;
    tags: string[];
}

interface CreatePostResponse {
    postId: string;
    createdAt: string;
}

export const createPost = onCall<CreatePostRequest>(async (request): Promise<CreatePostResponse> => {
    // Auth is automatically verified for callable functions
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const { title, content, tags } = request.data;

    // Validation
    if (!title || title.length > 200) {
        throw new HttpsError("invalid-argument", "Title must be 1-200 characters");
    }

    const postRef = await admin.firestore().collection("posts").add({
        title,
        content,
        tags,
        authorId: request.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        postId: postRef.id,
        createdAt: new Date().toISOString(),
    };
});
```

```kotlin
// Android: call the function
suspend fun createPost(title: String, content: String, tags: List<String>): String {
    val functions = Firebase.functions
    val data = hashMapOf(
        "title" to title,
        "content" to content,
        "tags" to tags
    )

    val result = functions.getHttpsCallable("createPost").call(data).await()
    val response = result.data as Map<*, *>
    return response["postId"] as String
}

// With timeout and region
val functions = Firebase.functions("us-central1")
functions.getHttpsCallable("createPost")
    .withTimeout(30, TimeUnit.SECONDS)
    .call(data)
    .await()
```

### Firestore Triggers

```typescript
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";

// Trigger on new document
export const onPostCreated = onDocumentCreated("posts/{postId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const post = snapshot.data();

    // Send notification to followers
    const followers = await admin.firestore()
        .collection("followers")
        .where("followingId", "==", post.authorId)
        .get();

    const notifications = followers.docs.map((doc) => ({
        userId: doc.data().followerId,
        message: `New post: ${post.title}`,
        postId: event.params.postId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }));

    const batch = admin.firestore().batch();
    notifications.forEach((notification) => {
        const ref = admin.firestore().collection("notifications").doc();
        batch.set(ref, notification);
    });
    await batch.commit();
});

// Trigger on update
export const onPostUpdated = onDocumentUpdated("posts/{postId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (before?.published === false && after?.published === true) {
        // Post was just published - index it, send emails, etc.
        console.log(`Post ${event.params.postId} was published`);
    }
});

// Trigger on delete
export const onPostDeleted = onDocumentDeleted("posts/{postId}", async (event) => {
    const postId = event.params.postId;
    // Clean up comments, likes, etc.
    const comments = await admin.firestore()
        .collection("comments")
        .where("postId", "==", postId)
        .get();

    const batch = admin.firestore().batch();
    comments.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
});
```

### Scheduled Functions

```typescript
import { onSchedule } from "firebase-functions/v2/scheduler";

// Runs every day at midnight UTC
export const dailyCleanup = onSchedule("0 0 * * *", async () => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldNotifications = await admin.firestore()
        .collection("notifications")
        .where("createdAt", "<", thirtyDaysAgo)
        .where("read", "==", true)
        .limit(500)
        .get();

    const batch = admin.firestore().batch();
    oldNotifications.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Deleted ${oldNotifications.size} old notifications`);
});

// Every 5 minutes
export const syncMetrics = onSchedule("every 5 minutes", async () => {
    // Aggregate and cache metrics
});
```

### Environment Config

```typescript
// firebase-functions v2 uses defineSecret and defineString
import { defineSecret, defineString } from "firebase-functions/params";

const stripeKey = defineSecret("STRIPE_SECRET_KEY");
const appUrl = defineString("APP_URL", { default: "https://myapp.com" });

export const processPayment = onCall(
    { secrets: [stripeKey] },
    async (request) => {
        const stripe = new Stripe(stripeKey.value());
        // ...
    }
);
```

```bash
# Set secrets
firebase functions:secrets:set STRIPE_SECRET_KEY
# Set config params
firebase functions:config:set app.url="https://myapp.com"
```

### Deployment

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:createPost

# Deploy with env
firebase deploy --only functions --project production
```

### Cold Start Optimization

```typescript
// Lazy initialization - import heavy modules only when needed
let _stripe: Stripe | null = null;
function getStripe(): Stripe {
    if (!_stripe) {
        const Stripe = require("stripe");
        _stripe = new Stripe(process.env.STRIPE_KEY);
    }
    return _stripe;
}

// Set minimum instances to avoid cold starts (costs more)
export const criticalEndpoint = onRequest(
    { minInstances: 1, memory: "256MiB", timeoutSeconds: 30 },
    async (req, res) => { /* ... */ }
);

// Keep global scope lean - only initialize what's always needed
admin.initializeApp();
const db = admin.firestore();
// Don't initialize Stripe, SendGrid, etc. at top level unless every function uses them
```

## Supabase Edge Functions

### Setup

```bash
supabase functions new my-function
```

### HTTP Function (Deno)

```typescript
// supabase/functions/process-order/index.ts
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // Get auth token from request
        const authHeader = req.headers.get("Authorization")!;

        // Create Supabase client with user's auth context
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            { global: { headers: { Authorization: authHeader } } }
        );

        const { orderId, action } = await req.json();

        // RLS is enforced because we use the user's token
        const { data: order, error } = await supabase
            .from("orders")
            .update({ status: action })
            .eq("id", orderId)
            .select()
            .single();

        if (error) throw error;

        return new Response(JSON.stringify(order), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
```

### Shared CORS Headers

```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
```

### Deployment

```bash
# Deploy single function
supabase functions deploy process-order

# Deploy all functions
supabase functions deploy

# Set secrets
supabase secrets set STRIPE_KEY=sk_live_xxx

# Test locally
supabase functions serve process-order --env-file .env.local
```

### Call from Android

```kotlin
// Using supabase-kt functions plugin
suspend fun processOrder(orderId: String, action: String): JsonElement {
    return client.functions.invoke("process-order") {
        body = buildJsonObject {
            put("orderId", orderId)
            put("action", action)
        }
    }.body<JsonElement>()
}
```

## Local Testing

### Firebase Emulator Suite

```bash
firebase emulators:start
# Runs Auth (9099), Firestore (8080), Functions (5001), Storage (9199)
```

```kotlin
// Connect Android app to emulators
if (BuildConfig.DEBUG) {
    Firebase.auth.useEmulator("10.0.2.2", 9099)
    Firebase.firestore.useEmulator("10.0.2.2", 8080)
    Firebase.functions.useEmulator("10.0.2.2", 5001)
    Firebase.storage.useEmulator("10.0.2.2", 9199)
}
```

### Supabase Local Dev

```bash
supabase start         # Starts local Postgres, Auth, Storage, Realtime, Edge Functions
supabase status        # Show URLs and keys
supabase db reset      # Reset database to migrations
supabase functions serve  # Hot-reload edge functions
```

### Error Handling Pattern

```typescript
// Firebase Cloud Functions
export const safeCallable = onCall(async (request) => {
    try {
        // Business logic
        return { success: true, data: result };
    } catch (error) {
        console.error("Function error:", error);

        if (error instanceof HttpsError) throw error;

        throw new HttpsError(
            "internal",
            "An unexpected error occurred",
            { originalError: (error as Error).message }
        );
    }
});
```

### Logging

```typescript
// Firebase - uses Cloud Logging
import { logger } from "firebase-functions";

logger.info("Processing order", { orderId, userId });
logger.warn("Rate limit approaching", { count });
logger.error("Payment failed", { error, orderId });

// Supabase Edge Functions - uses console
console.log("Processing:", JSON.stringify({ orderId }));
console.error("Failed:", error.message);
```
