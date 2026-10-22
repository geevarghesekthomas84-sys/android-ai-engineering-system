# Security Rules & Best Practices

## Firestore Security Rules

### Syntax Fundamentals

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Match specific collection
    match /collectionName/{documentId} {
      allow read: if <condition>;
      allow write: if <condition>;
    }

    // Match with wildcards (recursive)
    match /parentCollection/{parentId}/{document=**} {
      allow read: if <condition>;
    }
  }
}
```

### Access Control Granularity

```javascript
// Read operations (can be split)
allow read;             // = get + list
allow get;              // Single document read
allow list;             // Collection query

// Write operations (can be split)
allow write;            // = create + update + delete
allow create;           // New document only
allow update;           // Existing document only
allow delete;           // Remove document

// Combined
allow read, write: if <condition>;
```

### Request and Resource Objects

```javascript
// request.auth - the authenticated user
request.auth.uid               // User ID
request.auth.token.email       // Email
request.auth.token.email_verified // Email verification status
request.auth.token.phone_number // Phone
request.auth.token.name        // Display name
request.auth.token.firebase.sign_in_provider // "google.com", "password", etc.

// request.resource - the INCOMING data (create/update)
request.resource.data          // The data being written
request.resource.data.title    // A specific field

// resource - the EXISTING data in the document
resource.data                  // Current document data
resource.data.authorId         // Current field value
resource.id                    // Document ID

// request.time - server timestamp
request.time                   // When the request was made
```

### Common Patterns

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---- HELPER FUNCTIONS ----

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isSignedIn()
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    function hasRole(role) {
      return isSignedIn()
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role;
    }

    function isValidString(field, minLen, maxLen) {
      return request.resource.data[field] is string
        && request.resource.data[field].size() >= minLen
        && request.resource.data[field].size() <= maxLen;
    }

    function isValidTimestamp(field) {
      return request.resource.data[field] == request.time;
    }

    function documentExists(path) {
      return exists(/databases/$(database)/documents/$(path));
    }

    // ---- OWNER-ONLY ACCESS ----

    match /users/{userId} {
      // Anyone authenticated can read basic profile
      allow get: if isSignedIn();
      // Only list for admins (prevents scraping)
      allow list: if isAdmin();
      // Owner creates their own profile
      allow create: if isOwner(userId)
        && isValidString('name', 1, 100)
        && request.resource.data.role == 'user';  // Can't self-assign admin
      // Owner updates, but can't change role
      allow update: if isOwner(userId)
        && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']);
      // Owner or admin can delete
      allow delete: if isOwner(userId) || isAdmin();
    }

    // ---- ROLE-BASED ACCESS ----

    match /adminSettings/{settingId} {
      allow read: if isAdmin();
      allow write: if isAdmin();
    }

    match /moderatorQueue/{itemId} {
      allow read: if hasRole('moderator') || isAdmin();
      allow update: if hasRole('moderator') || isAdmin();
      allow create, delete: if isAdmin();
    }

    // ---- PUBLIC READ, PRIVATE WRITE ----

    match /publicContent/{contentId} {
      allow read: if true;  // No auth required
      allow create: if isSignedIn()
        && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if isSignedIn()
        && resource.data.authorId == request.auth.uid;
    }

    // ---- DATA VALIDATION ----

    match /posts/{postId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn()
        && request.resource.data.authorId == request.auth.uid
        && isValidString('title', 1, 200)
        && isValidString('content', 1, 50000)
        && request.resource.data.likes == 0
        && isValidTimestamp('createdAt');
      allow update: if isSignedIn()
        && resource.data.authorId == request.auth.uid
        // Prevent changing authorId or createdAt
        && request.resource.data.authorId == resource.data.authorId
        && request.resource.data.createdAt == resource.data.createdAt;
      allow delete: if isSignedIn()
        && (resource.data.authorId == request.auth.uid || isAdmin());

      // Subcollection: comments
      match /comments/{commentId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn()
          && request.resource.data.authorId == request.auth.uid
          && isValidString('text', 1, 2000);
        allow update: if request.auth.uid == resource.data.authorId;
        allow delete: if request.auth.uid == resource.data.authorId
          || request.auth.uid == get(/databases/$(database)/documents/posts/$(postId)).data.authorId;
      }
    }

    // ---- RATE LIMITING (approximate) ----

    match /rateLimited/{docId} {
      allow create: if isSignedIn()
        && (!documentExists('rateLimits/$(request.auth.uid)')
            || get(/databases/$(database)/documents/rateLimits/$(request.auth.uid)).data.lastWrite < request.time - duration.value(1, 'm'));
    }
  }
}
```

### Testing Firestore Rules

```bash
# Start emulator
firebase emulators:start --only firestore

# Run rules tests
npm test
```

```typescript
// firestore.rules.test.ts
import { initializeTestEnvironment, assertSucceeds, assertFails } from "@firebase/rules-unit-testing";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
        projectId: "test-project",
        firestore: {
            rules: fs.readFileSync("firestore.rules", "utf8"),
            host: "127.0.0.1",
            port: 8080,
        },
    });
});

afterAll(async () => {
    await testEnv.cleanup();
});

afterEach(async () => {
    await testEnv.clearFirestore();
});

test("authenticated user can read own profile", async () => {
    // Seed data as admin
    await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc("users/user123").set({
            name: "Alice",
            role: "user",
        });
    });

    // Test as authenticated user
    const alice = testEnv.authenticatedContext("user123", { email: "alice@test.com" });
    await assertSucceeds(alice.firestore().doc("users/user123").get());
});

test("user cannot read another user's private data as list", async () => {
    const bob = testEnv.authenticatedContext("bob");
    await assertFails(bob.firestore().collection("users").get());
});

test("unauthenticated user cannot write", async () => {
    const unauth = testEnv.unauthenticatedContext();
    await assertFails(unauth.firestore().doc("users/any").set({ name: "Hacker" }));
});

test("user cannot assign admin role to themselves", async () => {
    const user = testEnv.authenticatedContext("user1");
    await assertFails(
        user.firestore().doc("users/user1").set({
            name: "Eve",
            role: "admin",
        })
    );
});
```

## Supabase Row Level Security (RLS)

### Enable RLS

```sql
-- ALWAYS enable RLS on every table that holds user data
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners too (prevents accidental bypass)
ALTER TABLE todos FORCE ROW LEVEL SECURITY;
```

### Policy Syntax

```sql
CREATE POLICY "policy_name"
    ON table_name
    FOR [SELECT | INSERT | UPDATE | DELETE | ALL]
    TO [role_name | PUBLIC]
    USING (condition_for_existing_rows)      -- Filters rows for SELECT/UPDATE/DELETE
    WITH CHECK (condition_for_new_rows);     -- Validates data for INSERT/UPDATE
```

### Common RLS Patterns

```sql
-- ---- OWNER-ONLY ACCESS ----

CREATE POLICY "owner_select" ON todos
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "owner_insert" ON todos
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "owner_update" ON todos
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "owner_delete" ON todos
    FOR DELETE USING (auth.uid() = user_id);


-- ---- ROLE-BASED ACCESS ----

-- Using a roles table
CREATE POLICY "admin_full_access" ON todos
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_roles.user_id = auth.uid()
            AND user_roles.role = 'admin'
        )
    );

-- Using JWT custom claims (set via auth.admin)
CREATE POLICY "admin_via_jwt" ON todos
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
    );


-- ---- PUBLIC READ, PRIVATE WRITE ----

CREATE POLICY "public_read" ON posts
    FOR SELECT USING (published = true);

CREATE POLICY "author_write" ON posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "author_update" ON posts
    FOR UPDATE
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);


-- ---- TEAM/ORG ACCESS ----

CREATE POLICY "team_members_read" ON projects
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM team_members
            WHERE team_members.project_id = projects.id
            AND team_members.user_id = auth.uid()
        )
    );


-- ---- DATA VALIDATION IN POLICIES ----

CREATE POLICY "validate_insert" ON posts
    FOR INSERT WITH CHECK (
        auth.uid() = author_id
        AND char_length(title) BETWEEN 1 AND 200
        AND char_length(content) <= 50000
    );
```

### Testing RLS

```sql
-- Test as a specific user (in Supabase SQL Editor)
SET request.jwt.claims = '{"sub": "user-uuid-here", "role": "authenticated"}';
SET role = 'authenticated';

SELECT * FROM todos;  -- Should only show this user's todos

-- Reset
RESET role;
RESET request.jwt.claims;
```

## Security Best Practices

### Never Trust the Client

- All security rules and RLS policies run server-side. Client-side validation is UX only.
- Never store API keys with write access in the client app.
- Supabase `anon` key is safe to embed (RLS protects data). Never embed `service_role` key.
- Firebase `google-services.json` is safe to ship (security rules protect data).

### Server-Side Validation

```typescript
// Firebase: validate in Cloud Functions before writing
export const createPost = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");

    const { title, content } = request.data;

    // Server-side sanitization
    const cleanTitle = sanitizeHtml(title, { allowedTags: [] });
    const cleanContent = sanitizeHtml(content, { allowedTags: ["b", "i", "p", "br"] });

    if (cleanTitle.length === 0 || cleanTitle.length > 200) {
        throw new HttpsError("invalid-argument", "Invalid title length");
    }

    await admin.firestore().collection("posts").add({
        title: cleanTitle,
        content: cleanContent,
        authorId: request.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
});
```

```sql
-- Supabase: validate with database triggers
CREATE OR REPLACE FUNCTION validate_post()
RETURNS TRIGGER AS $$
BEGIN
    IF char_length(NEW.title) = 0 OR char_length(NEW.title) > 200 THEN
        RAISE EXCEPTION 'Title must be 1-200 characters';
    END IF;
    IF NEW.author_id != auth.uid() THEN
        RAISE EXCEPTION 'Cannot set author_id to another user';
    END IF;
    NEW.created_at := now();  -- Force server timestamp
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER validate_post_trigger
    BEFORE INSERT ON posts
    FOR EACH ROW EXECUTE FUNCTION validate_post();
```

### Checklist

- [ ] RLS/Security Rules enabled on every table/collection with user data
- [ ] No collection/table allows unrestricted write access
- [ ] User cannot modify fields they should not (role, createdAt, authorId)
- [ ] Admin endpoints validate admin role server-side, not just client-side
- [ ] File upload rules restrict file size and content type
- [ ] Rate limiting on expensive operations (Cloud Functions / Edge Functions)
- [ ] Service keys and admin SDKs used only in server-side code, never in client apps
- [ ] Test rules with emulator or policy testing before deploying to production
- [ ] Monitor security rules denials in Firebase Console or Supabase logs
- [ ] Sensitive operations (delete account, change email) require re-authentication
