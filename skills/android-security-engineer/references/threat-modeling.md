# Android Threat Modeling

## STRIDE Methodology for Mobile Apps

STRIDE is a systematic approach to identifying security threats. Each letter represents a threat category applied to Android application components.

### Spoofing (Identity)
- **App-level**: Fake apps impersonating your app on the Play Store or via sideloading. Users install a trojan that mimics your UI.
- **Network-level**: DNS spoofing redirecting API calls to an attacker-controlled server. Rogue Wi-Fi access points performing SSL stripping.
- **Component-level**: Malicious apps sending crafted intents to your exported components pretending to be a trusted caller.
- **Mitigations**: App signing verification, certificate pinning, caller identity validation with `Binder.getCallingUid()` and `PackageManager`, Android App Links with `assetlinks.json`.

### Tampering (Data Integrity)
- **Storage**: Modifying SharedPreferences, databases, or files on rooted devices. Patching the APK to bypass license checks or inject malicious code.
- **Transit**: Man-in-the-middle modifying API requests/responses. Injecting scripts into WebView content.
- **Runtime**: Using Frida or Xposed to hook methods and alter application behavior. Modifying memory values at runtime.
- **Mitigations**: Integrity checks on stored data (HMAC), TLS with certificate pinning, tamper detection, Play Integrity API, code obfuscation.

### Repudiation (Accountability)
- **User actions**: User denies performing a transaction. No audit trail for sensitive operations.
- **API calls**: No server-side logging of which device/user initiated a request.
- **Mitigations**: Server-side audit logging with device fingerprint and authenticated user ID, transaction signing, timestamped records with tamper-evident storage.

### Information Disclosure (Confidentiality)
- **Storage leaks**: Plaintext credentials in SharedPreferences, sensitive data in SQLite without encryption, data in app backup.
- **Network leaks**: Sensitive data in URL parameters (logged by proxies), HTTP cleartext traffic, excessive data in API responses.
- **Side channels**: Data in logcat output, clipboard contents, screenshot capture of sensitive screens, keyboard cache, autocomplete data.
- **Mitigations**: Encrypted storage, TLS enforcement, `FLAG_SECURE`, logging sanitization, input type flags (`textNoSuggestions`, `textPassword`).

### Denial of Service (Availability)
- **Local**: Corrupting local databases or files causing crashes. Filling device storage. Triggering ANR through intent flooding.
- **Network**: API rate limiting not enforced. Large payload attacks on parsers.
- **Mitigations**: Input validation, graceful error handling, database integrity checks, API rate limiting, request size limits.

### Elevation of Privilege
- **Component abuse**: Exploiting exported activities to bypass authentication screens. Using content provider SQL injection to access other apps' data.
- **Permission escalation**: Exploiting confused deputy attacks via pending intents. Gaining access to protected resources through vulnerable intermediate apps.
- **Mitigations**: Proper component export controls, parameterized queries, immutable pending intents, signature-level permissions.

## Attack Surface Identification

### Network Attack Surface
| Surface | Threats | Priority |
|---------|---------|----------|
| API endpoints | MITM, replay attacks, parameter tampering | Critical |
| WebSocket connections | Message injection, session hijacking | High |
| WebView content loading | Script injection, phishing | High |
| DNS resolution | DNS spoofing, DNS rebinding | Medium |
| Push notifications (FCM) | Message interception, spoofed notifications | Medium |

### Storage Attack Surface
| Surface | Threats | Priority |
|---------|---------|----------|
| SharedPreferences | Plaintext credential theft on rooted device | Critical |
| SQLite databases | Data extraction, SQL injection via content providers | High |
| Internal storage files | Data leakage through backup or file sharing | Medium |
| External storage | World-readable data, file replacement | High |
| Cache directories | Sensitive data in HTTP cache or image cache | Medium |

### IPC Attack Surface
| Surface | Threats | Priority |
|---------|---------|----------|
| Exported activities | Auth bypass, UI redressing | High |
| Exported services | Unauthorized service invocation | High |
| Content providers | Data leakage, SQL injection | Critical |
| Broadcast receivers | Intent spoofing, information disclosure | Medium |
| Deep links / App Links | Open redirect, parameter injection | High |

### UI Attack Surface
| Surface | Threats | Priority |
|---------|---------|----------|
| Login screen | Credential theft, shoulder surfing | Critical |
| WebView | Phishing, script injection, file access | High |
| Custom keyboards | Keystroke logging | Medium |
| Screenshots/Recent apps | Sensitive data visible in task switcher | Medium |
| Clipboard | Token/password leakage | Medium |

## Common Threat Scenarios

### Scenario 1: Man-in-the-Middle on Public Wi-Fi
**Attack**: User connects to a rogue Wi-Fi hotspot. Attacker intercepts API traffic, steals auth tokens, and replays them.
**Impact**: Full account takeover, data exfiltration.
**Mitigations**: Certificate pinning, short-lived tokens, token binding to device, cleartext traffic prevention.

### Scenario 2: Data Extraction on Rooted Device
**Attack**: Malware or a physical attacker with root access reads app's internal storage, extracts credentials and session tokens.
**Impact**: Credential theft, persistent unauthorized access.
**Mitigations**: Hardware-backed Keystore keys, biometric-gated access, encrypted storage with Keystore-derived keys, root detection.

### Scenario 3: Reverse Engineering and Repackaging
**Attack**: Attacker decompiles APK, extracts hardcoded API keys, modifies license checks, repackages with malware and distributes.
**Impact**: API abuse, malware distribution under your brand, revenue loss.
**Mitigations**: No hardcoded secrets, code obfuscation (R8), tamper detection, Play Integrity API, server-side validation.

### Scenario 4: Deep Link Injection
**Attack**: Attacker crafts a malicious deep link that navigates the user to a sensitive screen with attacker-controlled parameters, bypassing normal flow.
**Impact**: Auth bypass, parameter injection, open redirect to phishing site.
**Mitigations**: Validate deep link parameters server-side, use Android App Links with domain verification, sanitize all URI parameters.

### Scenario 5: Intent Injection via Exported Component
**Attack**: Malicious app sends a crafted intent to an exported activity or service, passing unexpected extras that alter application behavior.
**Impact**: Privilege escalation, data leakage, unauthorized operations.
**Mitigations**: Validate all intent extras, use signature-level permissions, minimize exported components, use `android:exported="false"` by default.

## Risk Assessment Matrix

| Likelihood / Impact | Low Impact | Medium Impact | High Impact | Critical Impact |
|---------------------|-----------|---------------|-------------|-----------------|
| **Very Likely** | Medium | High | Critical | Critical |
| **Likely** | Low | Medium | High | Critical |
| **Possible** | Low | Medium | High | High |
| **Unlikely** | Low | Low | Medium | High |
| **Rare** | Low | Low | Low | Medium |

### Impact Criteria
- **Critical**: Full account takeover, mass data breach, financial loss, regulatory violation.
- **High**: Individual user data exposure, authentication bypass, significant business logic abuse.
- **Medium**: Limited information disclosure, denial of service, integrity issues with partial impact.
- **Low**: Minor information leakage, cosmetic issues, theoretical vulnerabilities with no practical exploit.

### Likelihood Criteria
- **Very Likely**: Requires no special tools or knowledge. Automated exploitation possible.
- **Likely**: Requires basic tools (proxy, decompiler). Documented exploit techniques exist.
- **Possible**: Requires moderate skill and effort. Custom tooling needed.
- **Unlikely**: Requires advanced skill, physical access, or specific device conditions.
- **Rare**: Requires chaining multiple vulnerabilities or highly specific conditions.

## Threat Model Template

```
## Application: [App Name] v[Version]
## Date: [YYYY-MM-DD]
## Reviewer: [Name]

### 1. Application Overview
- Purpose: [Brief description]
- Sensitive data handled: [List data types and classification]
- External integrations: [APIs, SDKs, third-party services]
- Authentication method: [Password, biometric, OAuth, etc.]

### 2. Trust Boundaries
- Device boundary: [What stays on device vs. server]
- Network boundary: [Internal APIs vs. external services]
- User privilege boundary: [Anonymous, authenticated, admin]

### 3. Data Flow Diagram
[Describe or reference DFD showing data movement across trust boundaries]

### 4. Identified Threats
| ID | Category | Component | Threat | Likelihood | Impact | Risk | Mitigation |
|----|----------|-----------|--------|------------|--------|------|------------|
| T1 | [STRIDE] | [Component] | [Description] | [L/M/H] | [L/M/H/C] | [Score] | [Control] |

### 5. Residual Risks
[Threats accepted or partially mitigated with justification]

### 6. Action Items
| Priority | Action | Owner | Deadline |
|----------|--------|-------|----------|
```

## Review Checklist

Before release, verify each area has been threat-modeled:

- [ ] Authentication flows (login, registration, password reset, biometric enrollment)
- [ ] Session management (token storage, refresh, expiration, revocation)
- [ ] Sensitive data storage (credentials, PII, financial data, health data)
- [ ] Network communication (all API endpoints, WebSocket connections, WebView URLs)
- [ ] IPC mechanisms (exported components, deep links, custom URL schemes)
- [ ] Third-party SDKs (analytics, crash reporting, ads -- data they collect and transmit)
- [ ] Payment flows (in-app purchases, payment processing)
- [ ] Push notification handling (message content sensitivity, action handling)
- [ ] File sharing and receiving (intent filters for file types, content URI handling)
- [ ] Background processing (WorkManager tasks, foreground services with sensitive data)
- [ ] Error handling (stack traces in production, error messages revealing internals)
- [ ] Logging (no sensitive data in logcat, crash reports sanitized)
