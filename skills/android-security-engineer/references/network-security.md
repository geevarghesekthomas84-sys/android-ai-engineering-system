# Network Security

## Network Security Configuration

Android's `network_security_config.xml` provides declarative network security policy. Place it in `res/xml/` and reference it in `AndroidManifest.xml`:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config">
```

### Production Configuration (Strict)

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Block all cleartext traffic by default -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Certificate pinning for your API domain -->
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2027-01-01">
            <!-- Primary pin (SHA-256 of SubjectPublicKeyInfo) -->
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <!-- Backup pin (from a DIFFERENT CA, for rotation) -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

### Debug Configuration (Allows Proxy Inspection)

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <debug-overrides>
        <trust-anchors>
            <!-- Trust user-installed CAs only in debug builds -->
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>

    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2027-01-01">
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

The `<debug-overrides>` block only applies when `android:debuggable="true"` (debug builds), so production builds ignore it automatically.

## Certificate Pinning with OkHttp

For programmatic pinning (useful when you need dynamic pin updates or more control):

```kotlin
import okhttp3.CertificatePinner
import okhttp3.OkHttpClient

val certificatePinner = CertificatePinner.Builder()
    .add(
        "api.example.com",
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // leaf or intermediate
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // backup from different CA
    )
    .add(
        "cdn.example.com",
        "sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
    )
    .build()

val client = OkHttpClient.Builder()
    .certificatePinner(certificatePinner)
    .build()
```

### Extracting Pin Hashes

To get the SHA-256 pin of a certificate:

```bash
# From a live server
openssl s_client -connect api.example.com:443 -servername api.example.com < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64

# From a certificate file
openssl x509 -in certificate.pem -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

### Pin Rotation Strategy

1. Always include at least two pins: the current certificate and a backup from a different Certificate Authority.
2. Set an `expiration` date on the `pin-set`. After expiration, pinning is disabled rather than locking users out.
3. Before certificate rotation, push an app update that includes the new certificate's pin alongside the old one.
4. Consider a remote pin update mechanism (fetched over a pinned connection) for emergency rotation.
5. Monitor pin validation failures server-side to detect upcoming expiration issues.

## Preventing Cleartext Traffic

Beyond `network_security_config.xml`, enforce at the application level:

```kotlin
// In Application class or initialization
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    // Verify network security config is enforced
    val info = context.packageManager.getApplicationInfo(
        context.packageName, 0
    )
    if (info.flags and ApplicationInfo.FLAG_USES_CLEARTEXT_TRAFFIC != 0) {
        throw SecurityException("Cleartext traffic must be disabled")
    }
}
```

In `AndroidManifest.xml` as an additional declaration:

```xml
<application android:usesCleartextTraffic="false">
```

## SSL/TLS Version Enforcement

Force TLS 1.2+ and strong cipher suites:

```kotlin
import okhttp3.ConnectionSpec
import okhttp3.TlsVersion
import okhttp3.CipherSuite

val strictSpec = ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
    .tlsVersions(TlsVersion.TLS_1_2, TlsVersion.TLS_1_3)
    .cipherSuites(
        CipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
        CipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
        CipherSuite.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
        CipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
        CipherSuite.TLS_AES_128_GCM_SHA256,       // TLS 1.3
        CipherSuite.TLS_AES_256_GCM_SHA384,       // TLS 1.3
        CipherSuite.TLS_CHACHA20_POLY1305_SHA256   // TLS 1.3
    )
    .build()

val client = OkHttpClient.Builder()
    .connectionSpecs(listOf(strictSpec))
    .build()
```

## Mutual TLS (mTLS)

For high-security scenarios where the server must verify the client's identity:

```kotlin
import java.security.KeyStore
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory

fun createMtlsClient(
    clientCertKeyStore: KeyStore,
    clientCertPassword: CharArray,
    trustedCaKeyStore: KeyStore
): OkHttpClient {
    val keyManagerFactory = KeyManagerFactory.getInstance(
        KeyManagerFactory.getDefaultAlgorithm()
    ).apply {
        init(clientCertKeyStore, clientCertPassword)
    }

    val trustManagerFactory = TrustManagerFactory.getInstance(
        TrustManagerFactory.getDefaultAlgorithm()
    ).apply {
        init(trustedCaKeyStore)
    }

    val sslContext = SSLContext.getInstance("TLS").apply {
        init(
            keyManagerFactory.keyManagers,
            trustManagerFactory.trustManagers,
            java.security.SecureRandom()
        )
    }

    val trustManager = trustManagerFactory.trustManagers[0] as javax.net.ssl.X509TrustManager

    return OkHttpClient.Builder()
        .sslSocketFactory(sslContext.socketFactory, trustManager)
        .build()
}
```

Store the client certificate in Android Keystore for hardware protection. Import using `KeyStore.setKeyEntry()` with the private key and certificate chain.

## Proxy Detection

Detect when traffic may be intercepted by a proxy (useful for anti-fraud, not as a sole security measure):

```kotlin
fun isProxyConfigured(): Boolean {
    val proxyHost = System.getProperty("http.proxyHost")
    val proxyPort = System.getProperty("http.proxyPort")
    val httpsProxyHost = System.getProperty("https.proxyHost")

    return !proxyHost.isNullOrBlank() ||
           !httpsProxyHost.isNullOrBlank() ||
           !proxyPort.isNullOrBlank()
}

fun getProxyInfo(): java.net.Proxy {
    val connectivityManager = context.getSystemService(
        Context.CONNECTIVITY_SERVICE
    ) as ConnectivityManager
    val network = connectivityManager.activeNetwork
    val linkProperties = connectivityManager.getLinkProperties(network)
    val proxyInfo = linkProperties?.httpProxy

    return if (proxyInfo != null) {
        java.net.Proxy(
            java.net.Proxy.Type.HTTP,
            InetSocketAddress(proxyInfo.host, proxyInfo.port)
        )
    } else {
        java.net.Proxy.NO_PROXY
    }
}
```

## VPN Detection

```kotlin
fun isVpnActive(): Boolean {
    val connectivityManager = context.getSystemService(
        Context.CONNECTIVITY_SERVICE
    ) as ConnectivityManager

    val activeNetwork = connectivityManager.activeNetwork ?: return false
    val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false

    return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
}
```

**Note**: VPN and proxy detection are informational signals. Do not block users solely based on VPN usage -- legitimate users use VPNs for privacy. Use these signals as part of a broader risk assessment.

## Network Security by API Level

| Feature | Min API | Notes |
|---------|---------|-------|
| `network_security_config` | 24 (7.0) | Declarative network policy |
| Cleartext blocked by default | 28 (9.0) | `cleartextTrafficPermitted` defaults to `false` |
| TLS 1.3 support | 29 (10) | Available without custom config |
| Certificate Transparency | 28 (9.0) | Enforced for publicly trusted CAs |
| DNS-over-TLS | 28 (9.0) | System-level Private DNS setting |

For apps targeting below API 24, implement equivalent protections programmatically using OkHttp configuration.

## Common Mistakes

1. **Pinning only the leaf certificate**: Pin the intermediate CA or use SPKI pinning. Leaf certificates rotate frequently.
2. **No backup pin**: If the only pinned certificate expires or is revoked, users are permanently locked out. Always include a backup pin from a different CA.
3. **No pin expiration**: Set `expiration` on `pin-set` so a worst-case pin failure degrades to unpinned TLS rather than a total outage.
4. **Trusting user CAs in production**: Only trust user-installed CAs in debug builds via `debug-overrides`.
5. **Ignoring certificate validation errors**: Never implement a `TrustManager` that accepts all certificates or a `HostnameVerifier` that accepts all hostnames.
6. **Cleartext exceptions that are too broad**: If you must allow cleartext for a legacy endpoint, scope it to that specific domain, not the entire app.
