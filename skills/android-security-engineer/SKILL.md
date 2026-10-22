---
name: android-security-engineer
description: Android security engineering based on OWASP MASVS/MASTG covering threat modeling, secure storage, network security, authentication, code protection, and security testing
metadata:
  author: Custom
  keywords:
  - security
  - owasp
  - masvs
  - mastg
  - threat-modeling
  - keystore
  - certificate-pinning
  - security-testing
---

# Android Security Engineer

## Trigger Conditions

Activate this skill when the task involves any of the following:

- **Security review**: Reviewing Android code for vulnerabilities, auditing app security posture, preparing for penetration testing, or assessing compliance with OWASP MASVS.
- **Authentication implementation**: Implementing login flows, biometric authentication, token management, session handling, OAuth/OIDC integration, or multi-factor authentication.
- **Data protection**: Storing sensitive data (credentials, tokens, PII, health data), encrypting files or databases, configuring Android Keystore, or managing encryption keys.
- **API security**: Configuring TLS, implementing certificate pinning, securing API communication, preventing man-in-the-middle attacks, or handling network security configuration.
- **Release hardening**: Preparing an app for production release with obfuscation, tamper detection, debugger detection, root detection, Play Integrity checks, or removing debug artifacts.

## OWASP MASVS Categories

This skill covers all seven MASVS verification categories:

### MASVS-STORAGE
Secure storage of sensitive data including credentials, tokens, and PII. Covers Android Keystore, EncryptedSharedPreferences, EncryptedFile, encrypted DataStore, SQLCipher, secure temporary files, backup exclusions, and preventing data leakage through logs, clipboard, and screenshots.

**Reference**: `references/secure-storage.md`

### MASVS-CRYPTO
Proper use of cryptographic primitives. Covers key generation with Android Keystore (AES-GCM, RSA, EC), key attestation, biometric-bound keys, avoiding deprecated algorithms (DES, RC4, MD5, SHA-1 for signatures), proper IV/nonce handling, and secure random number generation with `SecureRandom`.

**Reference**: `references/secure-storage.md` (Keystore section)

### MASVS-AUTH
Authentication and session management. Covers biometric authentication with `BiometricPrompt` and `CryptoObject`, secure token storage, refresh token rotation, session expiration, brute-force protection, account lockout, OAuth 2.0 with PKCE, and proper logout with token revocation.

**Reference**: `references/auth-security.md`

### MASVS-NETWORK
Secure network communication. Covers TLS 1.2+ enforcement, `network_security_config.xml`, certificate pinning with pin-set and OkHttp `CertificatePinner`, cleartext traffic prevention, custom trust anchors for debug builds, mutual TLS, and proxy/VPN detection.

**Reference**: `references/network-security.md`

### MASVS-PLATFORM
Secure platform interaction. Covers exported component security (`android:exported`), intent validation, custom permissions, content provider hardening, deep link verification, WebView security (JavaScript interface risks, URL validation), `FileProvider` for secure file sharing, and pending intent security.

**Reference**: `references/component-security.md`

### MASVS-CODE
Code quality and security. Covers R8/ProGuard obfuscation, removing debug symbols, dependency scanning, SAST with detekt and Android Lint security rules, input validation, SQL injection prevention with parameterized queries, and secure coding patterns.

**Reference**: `references/code-protection.md`, `references/security-testing.md`

### MASVS-RESILIENCE
App integrity and anti-tampering. Covers tamper detection, debugger detection (`Debug.isDebuggerConnected()`), emulator detection, root detection, Play Integrity API (successor to SafetyNet), code signing verification, `FLAG_SECURE` for screenshots, and preventing screen recording.

**Reference**: `references/code-protection.md`

## Capabilities

This skill provides guidance and implementation patterns for:

1. **Threat modeling**: STRIDE-based threat modeling for Android apps, identifying attack surfaces (network, storage, IPC, UI), risk assessment, and mitigation planning. See `references/threat-modeling.md`.

2. **Secure credential storage**: Keystore-backed secret storage, biometric-gated access, encrypted preferences and files, avoiding hardcoded secrets.

3. **Android Keystore operations**: Key generation (AES, RSA, EC), key import, hardware-backed key attestation, setting key validity periods, user authentication requirements.

4. **TLS and certificate validation**: Enforcing TLS 1.2+, configuring certificate pins with backup pins, handling pin rotation, domain-specific network security configuration.

5. **Secure WebView**: Disabling unnecessary JavaScript, restricting `addJavascriptInterface` to API 17+, validating URLs in `shouldOverrideUrlLoading`, preventing file access, isolating WebView processes.

6. **Intent and component validation**: Validating incoming intents, restricting exported components, using signature-level permissions, securing broadcast receivers, preventing intent injection.

7. **Deep link validation**: Verifying deep link host and scheme, preventing open redirect through deep links, Android App Links with assetlinks.json, handling malformed URIs safely.

8. **API auth testing**: Testing token expiration, testing refresh flows, verifying token revocation, testing with expired/malformed tokens, checking for token leakage in logs and URLs.

9. **Dependency scanning**: Checking dependencies against known CVE databases, configuring OWASP Dependency-Check Gradle plugin, automating scans in CI, managing vulnerability suppressions.

10. **SAST/DAST**: Running detekt with security rule sets, Android Lint security checks, dynamic testing with Frida and mitmproxy, automated security test suites.

11. **Secure release configuration**: Production-ready build configuration with minification, obfuscation, debuggable=false, removing logging, configuring ProGuard/R8 rules, signing configuration.

12. **Security regression tests**: Writing tests that verify encryption works correctly, auth flows reject invalid input, sensitive data is not logged, exported components validate callers.

13. **Vulnerability reporting**: Structured vulnerability documentation with CVSS scoring, reproduction steps, impact assessment, and remediation guidance.

## Rules

- **For intentionally vulnerable labs, require isolated environments, synthetic data, and explicit authorization.** Never apply offensive techniques or create intentionally vulnerable code in production applications. Lab environments must be clearly separated from production, use only synthetic/mock data, and the developer must have documented explicit authorization for security testing activities.

- Always prefer the latest stable Android security APIs. When a deprecated API is encountered (e.g., `FingerprintManager` instead of `BiometricPrompt`, `SafetyNet` instead of `Play Integrity`), recommend and implement the modern replacement.

- Never hardcode secrets, API keys, or cryptographic keys in source code. Always use Android Keystore, encrypted storage, or build-time injection via `local.properties` or CI environment variables.

- Default to the most restrictive security posture: components unexported, cleartext blocked, backup disabled for sensitive data, TLS enforced, JavaScript disabled in WebView unless explicitly needed.

- When implementing security controls, include corresponding tests that verify both the positive case (control works) and negative case (attack is blocked).
