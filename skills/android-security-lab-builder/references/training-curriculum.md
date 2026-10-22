# Security Training Curriculum

> **DISCLAIMER**: This curriculum is designed for authorized security education in isolated lab environments only. All exercises use intentionally vulnerable apps with synthetic data running on emulators. Never apply exploitation techniques against systems without explicit written authorization.

## Curriculum Overview

A 7-module progressive curriculum aligned with the OWASP Mobile Top 10 (2024). Each module builds on skills from previous modules. Total estimated duration: 35-40 hours of lab time.

### Prerequisites

- Android development experience (Kotlin, Android Studio, Gradle)
- Basic command-line proficiency (adb, shell)
- Android emulator setup (see `lab-architecture.md`)
- No prior security experience required

---

## Module 1: Foundations and Lab Setup (4 hours)

**Objective**: Set up the isolated lab environment and understand the attacker's perspective.

### Topics

1. Security mindset: thinking like an attacker vs. thinking like a developer
2. The OWASP Mobile Top 10 — overview and real-world impact
3. Lab environment setup: emulator isolation, network configuration, synthetic data
4. Essential tools: `adb`, `jadx`, `apktool`, `mitmproxy`, `frida`
5. Android application architecture from a security perspective (APK structure, sandbox, IPC)

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Set up isolated emulator with proxy routing | 30 min | `lab-architecture.md` |
| Decompile a sample APK with jadx, identify components | 45 min | — |
| Use adb to inspect running app (processes, files, logs) | 30 min | — |
| Tour of the vulnerable lab app: identify the attack surface | 45 min | — |

### Assessment

- Demonstrate a working lab environment with proxy interception
- Identify at least 5 attack surface elements in the sample APK
- Submit a short write-up of findings using the provided template

---

## Module 2: Data Storage Security (5 hours)

**Objective**: Identify, exploit, and remediate insecure data storage patterns on Android.

**OWASP Mobile**: M9 — Insecure Data Storage

### Topics

1. Android storage mechanisms: SharedPreferences, SQLite/Room, internal/external files
2. The file system sandbox and its limitations (root, backup, debuggable apps)
3. EncryptedSharedPreferences and the Android Keystore
4. SQLCipher for encrypted databases
5. Backup and data extraction rules
6. Logcat and clipboard data exposure

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Extract plaintext credentials from SharedPreferences | 45 min | `storage-labs.md` Lab 1 |
| Pull and query an unencrypted SQLite database | 45 min | `storage-labs.md` Lab 2 |
| Exploit world-readable files and insecure backup | 45 min | `storage-labs.md` Labs 3-4 |
| Capture sensitive data from Logcat and clipboard | 30 min | `storage-labs.md` Labs 5-6 |
| Remediation: implement EncryptedSharedPreferences and SQLCipher | 60 min | `storage-labs.md` |

### Assessment

- Extract all synthetic credentials from the vulnerable storage lab APK
- Write a remediated version of one storage mechanism using proper encryption
- Explain why each fix works (written or oral)

---

## Module 3: Network Security (5 hours)

**Objective**: Intercept, analyze, and secure Android network communications.

**OWASP Mobile**: M3 — Insecure Communication

### Topics

1. TLS fundamentals and Android's network security configuration
2. Cleartext traffic detection and prevention
3. Certificate validation: how it works and how it breaks
4. Certificate pinning: rationale, implementation, and rotation strategy
5. Man-in-the-middle attack mechanics with mitmproxy and Burp Suite
6. Securing WebSocket and real-time connections

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Intercept cleartext HTTP login with mitmproxy | 45 min | `network-labs.md` Lab 1 |
| Exploit TrustAllCerts to MITM HTTPS traffic | 45 min | `network-labs.md` Lab 2 |
| Bypass missing certificate pinning with user CA | 45 min | `network-labs.md` Lab 3 |
| Capture WebSocket messages and API keys in transit | 30 min | `network-labs.md` Labs 4-5 |
| Remediation: implement network security config and pinning | 60 min | `network-labs.md` |

### Assessment

- Demonstrate full MITM interception of the vulnerable app's traffic
- Configure a working network security config with certificate pinning
- Explain the difference between TrustAllCerts bypass and pinning bypass

---

## Module 4: Cryptography (5 hours)

**Objective**: Identify weak cryptographic implementations and apply correct alternatives.

**OWASP Mobile**: M5 — Insufficient Cryptography

### Topics

1. Symmetric encryption: AES modes (ECB vs. CBC vs. GCM), key sizes
2. The Android Keystore: hardware-backed key management
3. Password hashing: why MD5/SHA1 are wrong, PBKDF2/Argon2 are right
4. Initialization vectors: purpose, randomness, and reuse attacks
5. Secure random number generation vs. `java.util.Random`
6. Recognizing and rejecting homebrew crypto

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Extract a hardcoded AES key from decompiled source and decrypt data | 45 min | `crypto-labs.md` Lab 1 |
| Break DES encryption and reverse MD5 password hashes | 45 min | `crypto-labs.md` Lab 2 |
| Demonstrate ECB mode pattern leakage with the penguin image | 30 min | `crypto-labs.md` Lab 3 |
| Predict outputs from `java.util.Random` seeded with time | 45 min | `crypto-labs.md` Lab 5 |
| Remediation: implement Keystore-backed AES-GCM encryption | 60 min | `crypto-labs.md` |

### Assessment

- Decrypt a flag encrypted with a hardcoded key found via jadx
- Explain why ECB mode is insecure for structured data
- Implement secure encryption using the Android Keystore

---

## Module 5: Injection and IPC Security (5 hours)

**Objective**: Exploit and remediate injection flaws in Android components and inter-process communication.

**OWASP Mobile**: M7 — Client Code Quality, M1 — Improper Platform Usage

### Topics

1. Android IPC: Intents, Content Providers, Broadcast Receivers, Services
2. Exported components and the principle of least privilege
3. SQL injection in Room `@RawQuery` and raw SQLite APIs
4. Intent injection and privilege escalation through exported Activities
5. Content Provider path traversal
6. WebView JavaScript injection and bridge security
7. Deep link hijacking and App Links as mitigation

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Perform SQL injection through a search field | 45 min | `injection-labs.md` Lab 1 |
| Escalate privileges via an exported Activity's Intent extras | 45 min | `injection-labs.md` Lab 2 |
| Traverse paths through an insecure Content Provider | 30 min | `injection-labs.md` Lab 3 |
| Exploit a WebView JavaScript bridge to exfiltrate data | 45 min | `injection-labs.md` Lab 4 |
| Hijack a custom deep link scheme | 30 min | `injection-labs.md` Lab 5 |
| Remediation: parameterized queries, unexported components, App Links | 60 min | `injection-labs.md` |

### Assessment

- Extract all synthetic records using SQL injection
- Demonstrate privilege escalation through an exported Activity
- Remediate one injection vulnerability and explain the security properties of the fix

---

## Module 6: Advanced Topics (5-6 hours)

**Objective**: Tackle real-world security patterns including root detection, debug logging, hardcoded secrets, and secure IPC.

**OWASP Mobile**: M4 — Insufficient Input/Output Validation, M8 — Security Misconfiguration

### Topics

1. Root and emulator detection: techniques and their limitations
2. Frida fundamentals: hooking Java and native methods at runtime
3. Debug logging and information disclosure in release builds
4. Hardcoded secrets: detection with grep, trufflehog, and static analysis
5. Secure IPC patterns: signature-level permissions, PendingIntent safety
6. ProGuard/R8 obfuscation: security value and limitations

### Lab Exercises

| Exercise | Duration | Reference |
|----------|----------|-----------|
| Bypass root detection checks with Frida hooks | 60 min | — |
| Extract secrets from BuildConfig, resources, and native libs | 45 min | — |
| Audit an APK for debug logging that leaks sensitive data | 30 min | `storage-labs.md` Lab 5 |
| Exploit an insecure PendingIntent (mutable, implicit) | 45 min | — |
| Static analysis: run a security scanner and triage findings | 45 min | — |

### Assessment

- Successfully bypass two different root detection techniques
- Identify and extract at least 3 hardcoded secrets from an APK
- Write a security audit summary for one lab app, with severity ratings

---

## Module 7: CTF Capstone and Assessment (6-8 hours)

**Objective**: Apply all skills in a timed CTF competition and demonstrate mastery through a final assessment.

### CTF Competition (4-5 hours)

Run a multi-challenge CTF using the challenge design from `ctf-design.md`:

| Challenge Pool | Count | Points |
|---------------|-------|--------|
| Beginner (Tier 1) | 4 | 600 |
| Intermediate (Tier 2) | 4 | 1600 |
| Advanced (Tier 3) | 3 | 2100 |
| Expert (Tier 4) | 1 | 700 |
| **Total** | **12** | **5000** |

- Participants work individually or in teams of 2-3
- Hints available at point cost (see `ctf-design.md`)
- Time bonuses for first solves
- All challenges run on isolated emulators with no internet access

### Final Assessment (2-3 hours)

A practical exam combining exploitation and remediation:

1. **Exploit Phase** (60 min): Given an unseen vulnerable APK, identify and exploit at least 3 distinct vulnerability classes. Document each exploit with steps, evidence, and impact.

2. **Remediation Phase** (60 min): Given one of the exploited vulnerabilities, implement a secure fix. The fix must pass the lab's automated validation tests.

3. **Report Phase** (30 min): Write a concise security assessment report covering:
   - Executive summary of findings
   - Vulnerability descriptions with CWE references
   - Risk severity ratings (Critical/High/Medium/Low)
   - Remediation recommendations with code examples

### Grading Rubric

| Component | Weight | Criteria |
|-----------|--------|----------|
| CTF score | 30% | Points earned / total possible |
| Exploit phase | 25% | Vulnerabilities found, exploitation quality, documentation |
| Remediation phase | 25% | Fix correctness, security properties, test pass rate |
| Report quality | 20% | Clarity, completeness, actionable recommendations |

---

## Instructor Notes

### Pacing Guidance

- Modules 1-4 form the core curriculum (19 hours) — sufficient for a 3-day intensive workshop
- Modules 5-7 extend to the full curriculum (35-40 hours) — suitable for a 5-day course or semester-long module
- Each module can be run independently if prerequisites are met

### Environment Requirements

- Each participant needs: Android Studio, a configured emulator (see `lab-architecture.md`), and the tool chain (adb, jadx, mitmproxy, frida)
- Instructor needs: pre-built lab APKs for each module, solution guides, a local flag validation server for the CTF
- Network: a lab-only WiFi network or VPN segment with no internet access is strongly recommended for multi-participant sessions

### Adapting Difficulty

- For developer audiences: emphasize remediation exercises, reduce exploitation time
- For security teams: emphasize advanced techniques (Frida, native reversing), add Tier 4 challenges
- For mixed audiences: pair security-focused participants with developers for the CTF team exercise
