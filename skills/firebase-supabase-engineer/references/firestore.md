# Cloud Firestore

## Data Model

Firestore organizes data as collections of documents. Documents contain fields and can hold subcollections. Documents are limited to 1 MB. Collection names and document IDs are strings.

```
users (collection)
  └── userId (document)
        ├── name: "Alice"
        ├── email: "alice@example.com"
        ├── createdAt: Timestamp
        └── posts (subcollection)
              └── postId (document)
                    ├── title: "Hello"
                    ├── content: "World"
                    └── likes: 42
```

## Kotlin Data Classes with Firestore

```kotlin
// Using @DocumentId for auto-populated document ID
data class User(
    @DocumentId val id: String = "",
    val name: String = "",
    val email: String = "",
    val avatarUrl: String? = null,
    val role: String = "user",
    @ServerTimestamp val createdAt: Timestamp? = null,
    @ServerTimestamp val updatedAt: Timestamp? = null
)

data class Post(
    @DocumentId val id: String = "",
    val authorId: String = "",
    val title: String = "",
    val content: String = "",
    val tags: List<String> = emptyList(),
    val likes: Int = 0,
    val published: Boolean = false,
    @ServerTimestamp val createdAt: Timestamp? = null
)
```

## CRUD Operations

```kotlin
class FirestoreRepository {
    private val db = Firebase.firestore
    private val usersRef = db.collection("users")
    private val postsRef = db.collection("posts")

    // CREATE - set with specific ID
    suspend fun createUser(user: User): Unit {
        usersRef.document(user.id).set(user).await()
    }

    // CREATE - add with auto-generated ID
    suspend fun createPost(post: Post): String {
        val docRef = postsRef.add(post).await()
        return docRef.id
    }

    // READ - single document
    suspend fun getUser(userId: String): User? {
        val snapshot = usersRef.document(userId).get().await()
        return snapshot.toObject<User>()
    }

    // READ - all documents in collection
    suspend fun getAllPosts(): List<Post> {
        val snapshot = postsRef.get().await()
        return snapshot.toObjects<Post>()
    }

    // UPDATE - specific fields only
    suspend fun updateUserName(userId: String, newName: String) {
        usersRef.document(userId).update("name", newName).await()
    }

    // UPDATE - multiple fields with map
    suspend fun updatePost(postId: String, updates: Map<String, Any>) {
        postsRef.document(postId).update(updates).await()
    }

    // UPDATE - increment numeric field
    suspend fun incrementLikes(postId: String) {
        postsRef.document(postId).update("likes", FieldValue.increment(1)).await()
    }

    // UPDATE - array operations
    suspend fun addTag(postId: String, tag: String) {
        postsRef.document(postId).update("tags", FieldValue.arrayUnion(tag)).await()
    }

    suspend fun removeTag(postId: String, tag: String) {
        postsRef.document(postId).update("tags", FieldValue.arrayRemove(tag)).await()
    }

    // DELETE
    suspend fun deletePost(postId: String) {
        postsRef.document(postId).delete().await()
    }

    // DELETE - specific field
    suspend fun removeAvatar(userId: String) {
        usersRef.document(userId).update("avatarUrl", FieldValue.delete()).await()
    }
}
```

## Queries

```kotlin
// Simple where clause
suspend fun getPublishedPosts(): List<Post> {
    return postsRef
        .whereEqualTo("published", true)
        .get().await()
        .toObjects<Post>()
}

// Compound queries (requires composite index)
suspend fun getRecentPublishedPosts(limit: Int = 20): List<Post> {
    return postsRef
        .whereEqualTo("published", true)
        .orderBy("createdAt", Query.Direction.DESCENDING)
        .limit(limit.toLong())
        .get().await()
        .toObjects<Post>()
}

// Range query
suspend fun getPopularPosts(minLikes: Int): List<Post> {
    return postsRef
        .whereGreaterThanOrEqualTo("likes", minLikes)
        .orderBy("likes", Query.Direction.DESCENDING)
        .get().await()
        .toObjects<Post>()
}

// Array contains
suspend fun getPostsByTag(tag: String): List<Post> {
    return postsRef
        .whereArrayContains("tags", tag)
        .get().await()
        .toObjects<Post>()
}

// In query (up to 30 values)
suspend fun getUsersByIds(ids: List<String>): List<User> {
    return usersRef
        .whereIn(FieldPath.documentId(), ids)
        .get().await()
        .toObjects<User>()
}

// Not equal
suspend fun getNonAdminUsers(): List<User> {
    return usersRef
        .whereNotEqualTo("role", "admin")
        .get().await()
        .toObjects<User>()
}
```

## Real-Time Listeners as Flow

```kotlin
// Single document listener
fun observeUser(userId: String): Flow<User?> = callbackFlow {
    val listener = usersRef.document(userId)
        .addSnapshotListener { snapshot, error ->
            if (error != null) {
                close(error)
                return@addSnapshotListener
            }
            trySend(snapshot?.toObject<User>())
        }
    awaitClose { listener.remove() }
}

// Collection query listener
fun observePublishedPosts(): Flow<List<Post>> = callbackFlow {
    val listener = postsRef
        .whereEqualTo("published", true)
        .orderBy("createdAt", Query.Direction.DESCENDING)
        .addSnapshotListener { snapshot, error ->
            if (error != null) {
                close(error)
                return@addSnapshotListener
            }
            val posts = snapshot?.toObjects<Post>() ?: emptyList()
            trySend(posts)
        }
    awaitClose { listener.remove() }
}

// Track document changes (added, modified, removed)
fun observePostChanges(): Flow<List<DocumentChange>> = callbackFlow {
    val listener = postsRef.addSnapshotListener { snapshot, error ->
        if (error != null) {
            close(error)
            return@addSnapshotListener
        }
        snapshot?.documentChanges?.let { trySend(it.toList()) }
    }
    awaitClose { listener.remove() }
}
```

## Pagination with Cursors

```kotlin
class PaginatedPostsRepository {
    private val db = Firebase.firestore
    private val pageSize = 20L
    private var lastDocument: DocumentSnapshot? = null

    suspend fun getFirstPage(): List<Post> {
        val snapshot = db.collection("posts")
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(pageSize)
            .get().await()

        lastDocument = snapshot.documents.lastOrNull()
        return snapshot.toObjects<Post>()
    }

    suspend fun getNextPage(): List<Post> {
        val last = lastDocument ?: return emptyList()
        val snapshot = db.collection("posts")
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .startAfter(last)
            .limit(pageSize)
            .get().await()

        lastDocument = snapshot.documents.lastOrNull()
        return snapshot.toObjects<Post>()
    }

    fun hasMore(): Boolean = lastDocument != null
}
```

## Transactions and Batch Writes

```kotlin
// Transaction: atomic read-then-write
suspend fun transferLikes(fromPostId: String, toPostId: String, count: Int) {
    db.runTransaction { transaction ->
        val fromRef = postsRef.document(fromPostId)
        val toRef = postsRef.document(toPostId)

        val fromSnapshot = transaction.get(fromRef)
        val currentLikes = fromSnapshot.getLong("likes") ?: 0

        if (currentLikes < count) {
            throw FirebaseFirestoreException(
                "Not enough likes",
                FirebaseFirestoreException.Code.ABORTED
            )
        }

        transaction.update(fromRef, "likes", FieldValue.increment(-count.toLong()))
        transaction.update(toRef, "likes", FieldValue.increment(count.toLong()))
    }.await()
}

// Batch write: atomic writes without reads (up to 500 operations)
suspend fun deleteAllUserPosts(userId: String) {
    val posts = postsRef.whereEqualTo("authorId", userId).get().await()
    db.runBatch { batch ->
        posts.documents.forEach { doc ->
            batch.delete(doc.reference)
        }
    }.await()
}
```

## Offline Persistence

```kotlin
// Enabled by default on Android. Configure cache size:
val settings = firestoreSettings {
    setLocalCacheSettings(persistentCacheSettings {
        setSizeBytes(FirestoreCacheSettings.CACHE_SIZE_UNLIMITED)
    })
}
db.firestoreSettings = settings

// Check if data came from cache
fun observeWithSource(docId: String): Flow<Pair<User?, String>> = callbackFlow {
    val listener = usersRef.document(docId)
        .addSnapshotListener { snapshot, error ->
            if (error != null) { close(error); return@addSnapshotListener }
            val source = if (snapshot?.metadata?.isFromCache == true) "cache" else "server"
            trySend(snapshot?.toObject<User>() to source)
        }
    awaitClose { listener.remove() }
}
```

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: owner read/write, others read name only
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth.uid == userId;
      allow update: if request.auth.uid == userId
                    && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']);
      allow delete: if request.auth.uid == userId;
    }

    // Posts: authenticated read, owner write
    match /posts/{postId} {
      allow read: if resource.data.published == true || request.auth.uid == resource.data.authorId;
      allow create: if request.auth != null
                    && request.resource.data.authorId == request.auth.uid
                    && request.resource.data.title.size() > 0
                    && request.resource.data.title.size() <= 200;
      allow update: if request.auth.uid == resource.data.authorId;
      allow delete: if request.auth.uid == resource.data.authorId;
    }

    // Helper function
    function isAdmin() {
      return request.auth != null
             && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Firestore Indexes

Composite indexes are required for queries that combine `where` + `orderBy` on different fields, multiple inequality filters, or `arrayContains` + `orderBy`. Create them in `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "published", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "tags", "arrayConfig": "CONTAINS" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

Deploy indexes: `firebase deploy --only firestore:indexes`

## Emulator Setup

```kotlin
if (BuildConfig.DEBUG) {
    Firebase.firestore.useEmulator("10.0.2.2", 8080)
}
```
