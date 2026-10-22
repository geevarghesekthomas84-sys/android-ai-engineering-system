# Cloud Storage

## Firebase Storage

### Setup

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.google.firebase:firebase-storage-ktx")
}

// Get reference
val storage = Firebase.storage
val storageRef = storage.reference
```

### Upload Files

```kotlin
class FirebaseStorageRepository {
    private val storageRef = Firebase.storage.reference

    // Upload ByteArray
    suspend fun uploadImage(path: String, data: ByteArray): Uri {
        val ref = storageRef.child(path)
        ref.putBytes(data).await()
        return ref.downloadUrl.await()
    }

    // Upload from Uri (gallery/camera)
    suspend fun uploadFromUri(path: String, fileUri: Uri): Uri {
        val ref = storageRef.child(path)
        ref.putFile(fileUri).await()
        return ref.downloadUrl.await()
    }

    // Upload with metadata
    suspend fun uploadWithMetadata(path: String, data: ByteArray, contentType: String): Uri {
        val ref = storageRef.child(path)
        val metadata = storageMetadata {
            this.contentType = contentType
            setCustomMetadata("uploadedBy", Firebase.auth.currentUser?.uid ?: "unknown")
            setCustomMetadata("timestamp", System.currentTimeMillis().toString())
        }
        ref.putBytes(data, metadata).await()
        return ref.downloadUrl.await()
    }

    // Upload with progress tracking
    fun uploadWithProgress(path: String, fileUri: Uri): Flow<UploadProgress> = callbackFlow {
        val ref = storageRef.child(path)
        val uploadTask = ref.putFile(fileUri)

        uploadTask.addOnProgressListener { snapshot ->
            val progress = (100.0 * snapshot.bytesTransferred / snapshot.totalByteCount).toInt()
            trySend(UploadProgress.InProgress(progress))
        }

        uploadTask.addOnSuccessListener {
            launch {
                val downloadUrl = ref.downloadUrl.await()
                trySend(UploadProgress.Success(downloadUrl))
                close()
            }
        }

        uploadTask.addOnFailureListener { exception ->
            trySend(UploadProgress.Error(exception))
            close(exception)
        }

        awaitClose { uploadTask.cancel() }
    }

    // Resumable upload (auto-resumed by SDK on network recovery)
    fun startResumableUpload(path: String, fileUri: Uri): UploadTask {
        val ref = storageRef.child(path)
        return ref.putFile(fileUri)
        // UploadTask automatically resumes after app restart via StorageReference.activeUploadTasks
    }
}

sealed class UploadProgress {
    data class InProgress(val percent: Int) : UploadProgress()
    data class Success(val downloadUrl: Uri) : UploadProgress()
    data class Error(val exception: Exception) : UploadProgress()
}
```

### Download Files

```kotlin
// Download to local file
suspend fun downloadToFile(path: String, localFile: File): File {
    val ref = storageRef.child(path)
    ref.getFile(localFile).await()
    return localFile
}

// Download as ByteArray (max 10 MB recommended)
suspend fun downloadBytes(path: String, maxSize: Long = 10L * 1024 * 1024): ByteArray {
    return storageRef.child(path).getBytes(maxSize).await()
}

// Get download URL (shareable, long-lived with security rules)
suspend fun getDownloadUrl(path: String): Uri {
    return storageRef.child(path).downloadUrl.await()
}
```

### Delete and Metadata

```kotlin
// Delete file
suspend fun deleteFile(path: String) {
    storageRef.child(path).delete().await()
}

// Get metadata
suspend fun getMetadata(path: String): StorageMetadata {
    return storageRef.child(path).metadata.await()
}

// Update metadata
suspend fun updateMetadata(path: String) {
    val newMetadata = storageMetadata {
        contentType = "image/jpeg"
        setCustomMetadata("status", "processed")
    }
    storageRef.child(path).updateMetadata(newMetadata).await()
}

// List files in directory
suspend fun listFiles(path: String): List<StorageReference> {
    val result = storageRef.child(path).listAll().await()
    return result.items // files
    // result.prefixes contains subdirectories
}
```

### Firebase Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // User avatars: owner read/write, anyone read
    match /avatars/{userId}/{fileName} {
      allow read: if true;
      allow write: if request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024 // 5 MB
                   && request.resource.contentType.matches('image/.*');
    }

    // Private files: owner only
    match /private/{userId}/{allPaths=**} {
      allow read, write: if request.auth.uid == userId;
    }

    // Shared files: authenticated users read, owner write
    match /shared/{fileId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 20 * 1024 * 1024;
    }
  }
}
```

## Supabase Storage

### Bucket Operations

```kotlin
class SupabaseStorageRepository @Inject constructor(
    private val client: SupabaseClient
) {
    // Upload to public bucket
    suspend fun uploadPublic(bucketId: String, path: String, data: ByteArray): String {
        val bucket = client.storage.from(bucketId)
        bucket.upload(path, data) {
            upsert = true
            contentType = ContentType.Image.JPEG
        }
        return bucket.publicUrl(path)
    }

    // Upload to private bucket
    suspend fun uploadPrivate(bucketId: String, path: String, data: ByteArray) {
        client.storage.from(bucketId).upload(path, data) {
            upsert = false
        }
    }

    // Download file
    suspend fun download(bucketId: String, path: String): ByteArray {
        return client.storage.from(bucketId).downloadAuthenticated(path)
    }

    // Signed URL for private files (time-limited)
    suspend fun getSignedUrl(bucketId: String, path: String, expiresInSeconds: Long = 3600): String {
        return client.storage.from(bucketId)
            .createSignedUrl(path, expiresIn = expiresInSeconds.seconds)
    }

    // Delete files
    suspend fun deleteFiles(bucketId: String, paths: List<String>) {
        client.storage.from(bucketId).delete(paths)
    }

    // List files
    suspend fun listFiles(bucketId: String, folder: String = ""): List<BucketItem> {
        return client.storage.from(bucketId).list(folder)
    }

    // Move/rename
    suspend fun moveFile(bucketId: String, from: String, to: String) {
        client.storage.from(bucketId).move(from, to)
    }

    // Copy file
    suspend fun copyFile(bucketId: String, from: String, to: String) {
        client.storage.from(bucketId).copy(from, to)
    }
}
```

### Supabase Storage RLS Policies

```sql
-- Create a storage bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- Allow authenticated uploads to own folder
CREATE POLICY "Users upload own avatar"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Allow public reads on avatars bucket
CREATE POLICY "Public avatar access"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

-- Allow users to delete own files
CREATE POLICY "Users delete own avatar"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );
```

## Image Compression Before Upload

```kotlin
suspend fun compressAndUpload(
    context: Context,
    imageUri: Uri,
    storagePath: String,
    maxWidth: Int = 1024,
    quality: Int = 80
): Uri {
    val compressed = withContext(Dispatchers.IO) {
        val inputStream = context.contentResolver.openInputStream(imageUri)
        val originalBitmap = BitmapFactory.decodeStream(inputStream)
        inputStream?.close()

        // Scale down
        val ratio = minOf(maxWidth.toFloat() / originalBitmap.width, 1f)
        val scaledBitmap = Bitmap.createScaledBitmap(
            originalBitmap,
            (originalBitmap.width * ratio).toInt(),
            (originalBitmap.height * ratio).toInt(),
            true
        )

        val outputStream = ByteArrayOutputStream()
        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
        originalBitmap.recycle()
        scaledBitmap.recycle()
        outputStream.toByteArray()
    }

    // Upload to Firebase Storage
    val ref = Firebase.storage.reference.child(storagePath)
    ref.putBytes(compressed).await()
    return ref.downloadUrl.await()
}
```

## Caching Downloaded Files

```kotlin
class StorageCacheManager(private val context: Context) {
    private val cacheDir = File(context.cacheDir, "storage_cache")

    init { cacheDir.mkdirs() }

    suspend fun getCachedOrDownload(storagePath: String): File {
        val cacheFile = File(cacheDir, storagePath.replace("/", "_"))

        if (cacheFile.exists() && !isExpired(cacheFile)) {
            return cacheFile
        }

        val ref = Firebase.storage.reference.child(storagePath)
        ref.getFile(cacheFile).await()
        return cacheFile
    }

    private fun isExpired(file: File, maxAgeMs: Long = 24 * 60 * 60 * 1000): Boolean {
        return System.currentTimeMillis() - file.lastModified() > maxAgeMs
    }

    fun clearCache() {
        cacheDir.listFiles()?.forEach { it.delete() }
    }

    fun getCacheSize(): Long {
        return cacheDir.listFiles()?.sumOf { it.length() } ?: 0L
    }
}
```

## Serving Optimized Images (Supabase Image Transformations)

```kotlin
// Supabase Storage supports on-the-fly image transformations via URL params
fun getOptimizedImageUrl(bucketId: String, path: String, width: Int, height: Int): String {
    val bucket = client.storage.from(bucketId)
    return bucket.publicUrl(path) {
        transform {
            this.width = width
            this.height = height
            this.resize = ImageTransformation.Resize.COVER
            this.quality = 80
            this.format = "webp"
        }
    }
}
```
