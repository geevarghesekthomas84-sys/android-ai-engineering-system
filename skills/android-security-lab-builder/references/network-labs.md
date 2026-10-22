# Network Security Vulnerability Labs

> **DISCLAIMER**: All code in this document contains INTENTIONAL vulnerabilities for security education in isolated environments only. All traffic interception must target only the lab's own emulator and local backend. Never intercept traffic on networks or devices you do not own.

## Lab 1: Cleartext HTTP Communication

**Learning Objective**: Demonstrate how cleartext HTTP exposes sensitive data in transit and how to enforce TLS with network security configuration.

**OWASP Mobile**: M3 — Insecure Communication

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — cleartext HTTP
// VULNERABILITY: CWE-319 — Cleartext transmission of sensitive information

class InsecureApiClient {

    private val client = OkHttpClient.Builder().build()

    // VULNERABILITY: Credentials sent over unencrypted HTTP
    fun login(username: String, password: String): Response {
        val body = """{"username":"$username","password":"$password"}"""
            .toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("http://10.0.2.2:8080/api/login")  // VULNERABILITY: HTTP, not HTTPS
            .post(body)
            .build()

        return client.newCall(request).execute()
    }
}
```

```xml
<!-- AndroidManifest.xml -->
<!-- VULNERABILITY: Cleartext traffic permitted -->
<application android:usesCleartextTraffic="true">
```

### Exploitation with mitmproxy

```bash
# 1. Start mitmproxy on host machine
mitmproxy --mode regular --listen-port 8080 --set console_focus_follow=true

# 2. Launch emulator with proxy
emulator -avd security-lab -http-proxy http://127.0.0.1:8080

# 3. Trigger the login in the app

# 4. In mitmproxy, observe the plaintext request body:
#    POST http://10.0.2.2:8080/api/login
#    {"username":"user1@test.invalid","password":"password1"}
```

### Remediation

```xml
<!-- res/xml/network_security_config.xml -->
<!-- FIX: Deny cleartext traffic to all domains -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- FIX: Allow cleartext only for the local lab server in debug builds -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

```xml
<!-- AndroidManifest.xml -->
<!-- FIX: Reference the network security config -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false">
```

---

## Lab 2: Disabled Certificate Validation (TrustAllCerts)

**Learning Objective**: Show why overriding X509TrustManager to trust all certificates enables trivial man-in-the-middle attacks.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — disabled certificate validation
// VULNERABILITY: CWE-295 — Improper certificate validation

object TrustAllCerts {

    // VULNERABILITY: TrustManager that accepts ANY certificate
    private val trustAllManager = object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
    }

    // VULNERABILITY: HostnameVerifier that accepts ANY hostname
    private val trustAllHostnames = HostnameVerifier { _, _ -> true }

    fun createInsecureClient(): OkHttpClient {
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, arrayOf(trustAllManager), SecureRandom())

        return OkHttpClient.Builder()
            .sslSocketFactory(sslContext.socketFactory, trustAllManager)
            .hostnameVerifier(trustAllHostnames)  // VULNERABILITY: no hostname check
            .build()
    }
}
```

### Exploitation with Burp Suite

```bash
# 1. Configure Burp proxy on 127.0.0.1:8080
# 2. Launch emulator with proxy pointing to Burp
emulator -avd security-lab -http-proxy http://127.0.0.1:8080

# 3. Burp will present its own CA certificate for HTTPS connections
# 4. Because TrustAllCerts accepts ANY certificate, the app connects without error
# 5. All HTTPS traffic is now visible in Burp's HTTP History tab in plaintext

# The app sends credentials and tokens over "HTTPS" but the proxy sees everything:
# POST https://10.0.2.2:8443/api/login
# Authorization: Bearer eyJhbGciOiJIUzI1...
```

### Remediation

```kotlin
// FIX: Use the default OkHttpClient which validates certificates properly
class SecureApiClient {
    // FIX: Default OkHttpClient uses the system trust store and validates hostnames
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .build()

    fun login(username: String, password: String): Response {
        val body = """{"username":"$username","password":"$password"}"""
            .toRequestBody("application/json".toMediaType())

        // FIX: HTTPS with proper certificate validation
        val request = Request.Builder()
            .url("https://10.0.2.2:8443/api/login")
            .post(body)
            .build()

        return client.newCall(request).execute()
    }
}
```

---

## Lab 3: Missing Certificate Pinning

**Learning Objective**: Demonstrate how a valid but attacker-controlled certificate (from a compromised CA or corporate proxy) can intercept traffic when pinning is absent.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — no certificate pinning
// VULNERABILITY: CWE-295 — App trusts any CA-signed certificate

class NoPinningApiClient {
    // VULNERABILITY: No certificate pinning — any CA-signed cert is accepted
    private val client = OkHttpClient.Builder().build()

    fun fetchAccountData(): String {
        val request = Request.Builder()
            .url("https://10.0.2.2:8443/api/account")
            .build()
        return client.newCall(request).execute().body?.string() ?: ""
    }
}
```

### Exploitation Steps

```bash
# 1. Install mitmproxy CA certificate on the emulator as a user cert
adb push ~/.mitmproxy/mitmproxy-ca-cert.cer /sdcard/
# Then: Settings -> Security -> Install from storage -> select the cert

# 2. Add the lab app to network_security_config to trust user CAs (already present
#    in the vulnerable variant)

# 3. All HTTPS traffic is now interceptable despite using TLS, because the
#    mitmproxy CA is trusted and there is no pin to reject it.
```

### Remediation

```kotlin
// FIX: Certificate pinning with OkHttp CertificatePinner
class PinnedApiClient {
    // FIX: Pin the server's public key hash — reject any cert that doesn't match
    private val certificatePinner = CertificatePinner.Builder()
        .add("api.lab.local", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=") // Lab pin
        .add("api.lab.local", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=") // Backup pin
        .build()

    private val client = OkHttpClient.Builder()
        .certificatePinner(certificatePinner)
        .build()

    fun fetchAccountData(): String {
        val request = Request.Builder()
            .url("https://api.lab.local:8443/api/account")
            .build()
        return client.newCall(request).execute().body?.string() ?: ""
    }
}
```

Also use the network security configuration for defense in depth:

```xml
<!-- res/xml/network_security_config.xml -->
<!-- FIX: Pin certificates at the config level -->
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">api.lab.local</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

---

## Lab 4: Insecure WebSocket Connection

**Learning Objective**: Show how unencrypted WebSocket connections (ws://) expose real-time data streams.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — unencrypted WebSocket
// VULNERABILITY: CWE-319 — Cleartext WebSocket transmits messages in plaintext

class InsecureChatClient {
    private val client = OkHttpClient()

    fun connect(): WebSocket {
        // VULNERABILITY: ws:// instead of wss:// — all messages in cleartext
        val request = Request.Builder()
            .url("ws://10.0.2.2:8080/chat")
            .build()

        return client.newWebSocket(request, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                // Messages visible to any network observer
                Log.d("Chat", "Received: $text")  // VULNERABILITY: also logged
            }
        })
    }
}
```

### Exploitation

```bash
# Use mitmproxy to see WebSocket frames in cleartext
mitmproxy --mode regular --listen-port 8080
# WebSocket messages appear in the flow list, fully readable
```

### Remediation

```kotlin
// FIX: Use wss:// for encrypted WebSocket and validate the server certificate
class SecureChatClient {
    private val client = OkHttpClient.Builder()
        .certificatePinner(certificatePinner)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    fun connect(): WebSocket {
        // FIX: wss:// encrypts the WebSocket connection with TLS
        val request = Request.Builder()
            .url("wss://10.0.2.2:8443/chat")
            .build()

        return client.newWebSocket(request, chatListener)
    }
}
```

---

## Lab 5: Exposed API Keys in Traffic

**Learning Objective**: Demonstrate how hardcoded API keys in request headers or URLs are trivially captured.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — API key in traffic
// VULNERABILITY: CWE-798 — Hardcoded credentials sent in every request

class InsecureApiService {
    // VULNERABILITY: API key hardcoded and sent as a query parameter
    private val apiKey = "lab_test_key_AAAA1111BBBB2222"

    fun fetchData(): Response {
        val request = Request.Builder()
            // VULNERABILITY: API key in URL — logged by proxies, servers, browser history
            .url("http://10.0.2.2:8080/api/data?api_key=$apiKey")
            .build()
        return client.newCall(request).execute()
    }
}
```

### Remediation

```kotlin
// FIX: Use short-lived OAuth tokens instead of static API keys
// Store refresh tokens in EncryptedSharedPreferences (see storage-labs.md)
class SecureApiService(private val tokenProvider: TokenProvider) {
    fun fetchData(): Response {
        val token = tokenProvider.getAccessToken()  // FIX: Short-lived, rotatable
        val request = Request.Builder()
            .url("https://10.0.2.2:8443/api/data")
            .header("Authorization", "Bearer $token")  // FIX: In header, not URL
            .build()
        return client.newCall(request).execute()
    }
}
```

---

## Lab 6: Missing Authentication on API Endpoints

**Learning Objective**: Show how unauthenticated API endpoints allow unauthorized data access.

### Vulnerable Backend (Ktor)

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — no authentication on sensitive endpoint
// VULNERABILITY: CWE-306 — Missing authentication for critical function

fun Application.configureRouting() {
    routing {
        // VULNERABILITY: No authentication required — anyone can access all user data
        get("/api/users") {
            call.respond(SyntheticDataGenerator.generateUsers(50))
        }

        // VULNERABILITY: No authorization check — any user can access any other user's data
        get("/api/users/{id}") {
            val id = call.parameters["id"]?.toIntOrNull()
            call.respond(SyntheticDataGenerator.generateUser(id ?: 1))
        }
    }
}
```

### Exploitation

```bash
# No auth token needed — direct curl reveals all data
curl http://127.0.0.1:8443/api/users
# Returns full list of user records including SSN and credit cards

curl http://127.0.0.1:8443/api/users/1
# Returns specific user without any authentication
```

### Remediation

```kotlin
// FIX: Require authentication and enforce authorization
fun Application.configureRouting() {
    install(Authentication) {
        bearer("auth-bearer") {
            authenticate { tokenCredential ->
                validateToken(tokenCredential.token)  // FIX: Validate JWT
            }
        }
    }

    routing {
        authenticate("auth-bearer") {
            get("/api/users/{id}") {
                val requestingUser = call.principal<UserPrincipal>()!!
                val targetId = call.parameters["id"]?.toIntOrNull()
                // FIX: Authorization — users can only access their own data
                if (requestingUser.id != targetId && !requestingUser.isAdmin) {
                    call.respond(HttpStatusCode.Forbidden, "Access denied")
                    return@get
                }
                call.respond(userRepository.findById(targetId!!))
            }
        }
    }
}
```
