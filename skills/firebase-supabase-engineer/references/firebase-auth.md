# Firebase Authentication

## Email/Password Authentication

```kotlin
// Sign up
val auth = Firebase.auth

suspend fun signUp(email: String, password: String): AuthResult {
    return auth.createUserWithEmailAndPassword(email, password).await()
}

// Sign in
suspend fun signIn(email: String, password: String): AuthResult {
    return auth.signInWithEmailAndPassword(email, password).await()
}

// Password reset
suspend fun sendPasswordReset(email: String) {
    auth.sendPasswordResetEmail(email).await()
}

// Email verification
suspend fun sendEmailVerification() {
    auth.currentUser?.sendEmailVerification()?.await()
}

// Update password
suspend fun updatePassword(newPassword: String) {
    auth.currentUser?.updatePassword(newPassword)?.await()
}
```

## Google Sign-In (Credential Manager API)

```kotlin
// build.gradle.kts
// implementation("androidx.credentials:credentials:1.5.0")
// implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
// implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

class GoogleAuthHelper(private val context: Context) {
    private val credentialManager = CredentialManager.create(context)

    suspend fun signInWithGoogle(): AuthResult {
        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(BuildConfig.WEB_CLIENT_ID)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val result = credentialManager.getCredential(context as Activity, request)
        val credential = result.credential
        val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
        val firebaseCredential = GoogleAuthProvider.getCredential(googleIdTokenCredential.idToken, null)
        return Firebase.auth.signInWithCredential(firebaseCredential).await()
    }
}
```

## Phone Authentication

```kotlin
class PhoneAuthHelper(private val activity: Activity) {
    private val auth = Firebase.auth

    fun sendVerificationCode(
        phoneNumber: String,
        onCodeSent: (String) -> Unit,
        onVerificationCompleted: (PhoneAuthCredential) -> Unit,
        onFailed: (FirebaseException) -> Unit
    ) {
        val options = PhoneAuthOptions.newBuilder(auth)
            .setPhoneNumber(phoneNumber)
            .setTimeout(60L, TimeUnit.SECONDS)
            .setActivity(activity)
            .setCallbacks(object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
                override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                    onVerificationCompleted(credential)
                }
                override fun onVerificationFailed(e: FirebaseException) {
                    onFailed(e)
                }
                override fun onCodeSent(verificationId: String, token: PhoneAuthProvider.ForceResendingToken) {
                    onCodeSent(verificationId)
                }
            })
            .build()
        PhoneAuthProvider.verifyPhoneNumber(options)
    }

    suspend fun verifyCode(verificationId: String, code: String): AuthResult {
        val credential = PhoneAuthProvider.getCredential(verificationId, code)
        return auth.signInWithCredential(credential).await()
    }
}
```

## Anonymous Authentication

```kotlin
suspend fun signInAnonymously(): AuthResult {
    return Firebase.auth.signInAnonymously().await()
}

// Convert anonymous account to permanent
suspend fun linkWithEmail(email: String, password: String): AuthResult {
    val credential = EmailAuthProvider.getCredential(email, password)
    return Firebase.auth.currentUser!!.linkWithCredential(credential).await()
}
```

## Multi-Factor Authentication (MFA)

```kotlin
// Enroll second factor (phone)
suspend fun enrollMfa(activity: Activity, phoneNumber: String) {
    val user = Firebase.auth.currentUser ?: return
    val session = user.multiFactor.session.await()

    val phoneAuthOptions = PhoneMultiFactorGenerator.getPhoneAuthOptions(
        PhoneAuthOptions.newBuilder()
            .setPhoneNumber(phoneNumber)
            .setTimeout(30L, TimeUnit.SECONDS)
            .setMultiFactorSession(session)
            .setActivity(activity)
            .setCallbacks(verificationCallbacks)
            .build()
    )
    // After code verification:
    val credential = PhoneAuthProvider.getCredential(verificationId, code)
    val assertion = PhoneMultiFactorGenerator.getAssertion(credential)
    user.multiFactor.enroll(assertion, "Phone number").await()
}

// Handle MFA during sign-in
fun handleMfaChallenge(exception: FirebaseAuthMultiFactorException) {
    val resolver = exception.resolver
    val hints = resolver.hints // List of enrolled factors
    // Prompt user to select factor, then verify
}
```

## Custom Tokens (Server-Side)

```typescript
// Cloud Function to create custom token
import * as admin from "firebase-admin";

export const createCustomToken = functions.https.onCall(async (data, context) => {
    const uid = data.uid;
    const additionalClaims = { role: data.role };
    return admin.auth().createCustomToken(uid, additionalClaims);
});
```

```kotlin
// Android: sign in with custom token
suspend fun signInWithCustomToken(token: String): AuthResult {
    return Firebase.auth.signInWithCustomToken(token).await()
}
```

## Auth State as Flow (Jetpack Compose Integration)

```kotlin
// AuthRepository.kt
class AuthRepository {
    private val auth = Firebase.auth

    val currentUser: Flow<FirebaseUser?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser)
        }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    val isAuthenticated: Flow<Boolean> = currentUser.map { it != null }

    fun getIdToken(forceRefresh: Boolean = false): Flow<String?> = flow {
        val token = auth.currentUser?.getIdToken(forceRefresh)?.await()?.token
        emit(token)
    }
}

// AuthViewModel.kt
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    val authState = authRepository.currentUser
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val isAuthenticated = authRepository.isAuthenticated
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    fun signOut() {
        Firebase.auth.signOut()
    }
}

// Compose UI
@Composable
fun AuthGate(viewModel: AuthViewModel = hiltViewModel()) {
    val isAuthenticated by viewModel.isAuthenticated.collectAsStateWithLifecycle()

    if (isAuthenticated) {
        HomeScreen()
    } else {
        LoginScreen()
    }
}
```

## Secure Token Handling

```kotlin
// Get fresh ID token for API calls
suspend fun getAuthHeader(): String {
    val token = Firebase.auth.currentUser
        ?.getIdToken(false)?.await()?.token
        ?: throw IllegalStateException("User not authenticated")
    return "Bearer $token"
}

// OkHttp Interceptor for automatic token injection
class FirebaseAuthInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = runBlocking {
            Firebase.auth.currentUser?.getIdToken(false)?.await()?.token
        }
        val request = chain.request().newBuilder()
            .addHeader("Authorization", "Bearer $token")
            .build()
        return chain.proceed(request)
    }
}
```

## Auth Emulator for Testing

```kotlin
// In Application.onCreate() or test setup
if (BuildConfig.DEBUG) {
    Firebase.auth.useEmulator("10.0.2.2", 9099) // Android emulator host
}
```

## Linking Multiple Auth Providers

```kotlin
// Link Google to existing email account
suspend fun linkGoogleAccount(idToken: String): AuthResult {
    val credential = GoogleAuthProvider.getCredential(idToken, null)
    return Firebase.auth.currentUser!!.linkWithCredential(credential).await()
}

// Unlink provider
suspend fun unlinkProvider(providerId: String): FirebaseUser {
    return Firebase.auth.currentUser!!.unlink(providerId).await()
}

// Get linked providers
fun getLinkedProviders(): List<String> {
    return Firebase.auth.currentUser?.providerData?.map { it.providerId } ?: emptyList()
}
```

## Re-authentication (for sensitive operations)

```kotlin
suspend fun reauthenticate(email: String, password: String) {
    val credential = EmailAuthProvider.getCredential(email, password)
    Firebase.auth.currentUser?.reauthenticate(credential)?.await()
}

suspend fun deleteAccount() {
    // Must reauthenticate first for security
    Firebase.auth.currentUser?.delete()?.await()
}
```
