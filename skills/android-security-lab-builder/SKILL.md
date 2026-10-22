---
name: android-security-lab-builder
description: Build intentionally vulnerable Android apps for security education, CTF challenges, and authorized penetration testing practice in isolated environments
metadata:
  author: Custom
  keywords:
  - security-lab
  - vulnerable-app
  - ctf
  - penetration-testing
  - security-education
  - owasp
  - training
---

# Android Security Lab Builder

## Trigger Conditions

Activate this skill when:

- The user asks to create a security training lab, vulnerable-by-design Android app, or CTF challenge
- The user wants to demonstrate a specific Android vulnerability class (OWASP Mobile Top 10)
- The user is building a penetration testing practice environment
- The user requests a security training curriculum or workshop materials
- The user needs exploitation and remediation guides for Android vulnerabilities
- Keywords: "security lab", "vulnerable app", "CTF", "capture the flag", "pentest training", "OWASP mobile", "security exercise", "vulnerability demo"

## CRITICAL SAFETY RULES

These rules are non-negotiable and must be followed for every piece of code produced by this skill:

1. **ISOLATED ENVIRONMENTS ONLY** — All vulnerable apps must run exclusively in emulators or dedicated test devices on isolated networks. Never configure labs to run on devices connected to production networks.

2. **SYNTHETIC DATA ONLY** — All data used in labs must be entirely fictional. Use generated names, fake credentials, dummy credit card numbers (from standard test ranges like 4111-1111-1111-1111), and placeholder API keys. Never use real user data, real API keys, or real credentials.

3. **EXPLICIT AUTHORIZATION REQUIRED** — Every lab project must include a prominent README stating the app is intentionally vulnerable, that it must only be used in authorized testing environments, and that deploying it to any production environment or using it against systems without explicit written permission is prohibited.

4. **NEVER DEPLOY TO PRODUCTION** — Lab apps must have safeguards preventing production deployment:
   - `applicationId` must include `.vulnerable.lab` or `.securitylab` suffix
   - The `AndroidManifest.xml` must include `android:testOnly="true"`
   - Build configurations must exclude release signing configs
   - The app must display a persistent warning banner in all screens

5. **CLEAR WARNING LABELS** — Every file containing intentional vulnerabilities must include:
   - A file-level comment: `// SECURITY LAB: This code contains INTENTIONAL vulnerabilities for educational purposes`
   - Each vulnerability marked with: `// VULNERABILITY: [Category] - [Description]`
   - Each fix marked with: `// FIX: [Description of remediation]`

6. **NO REAL EXPLOIT PAYLOADS** — Do not include payloads that target real services or infrastructure. All exploitation examples must target only the lab app itself.

7. **SCOPE LIMITATION** — Labs must not include functionality that could be weaponized beyond the educational scope: no network scanners, no credential harvesters targeting external services, no code that phones home to external servers.

## Capabilities

This skill builds intentionally vulnerable Android applications covering these vulnerability categories:

### Data Storage Vulnerabilities
- Plaintext credential storage in SharedPreferences
- Unencrypted SQLite databases with sensitive data
- World-readable file permissions
- Insecure backup configuration (`android:allowBackup="true"` with sensitive data)
- Sensitive data logged to Logcat
- Clipboard data exposure

### Network Security Vulnerabilities
- Cleartext HTTP communication for sensitive operations
- Disabled certificate validation (TrustAllCerts pattern)
- Missing certificate pinning
- Insecure WebSocket connections
- API keys exposed in network traffic
- Missing authentication on API endpoints

### Cryptography Vulnerabilities
- Hardcoded encryption keys in source code
- Weak algorithms (DES, MD5 for password hashing)
- ECB mode encryption revealing patterns
- Predictable initialization vectors
- Insecure random number generation (`java.util.Random` for security)
- Custom/homebrew crypto implementations

### Injection Vulnerabilities
- SQL injection via raw queries and `@RawQuery` abuse
- Intent injection through exported Activities
- Content Provider path traversal
- WebView JavaScript injection
- Deep link hijacking and scheme abuse

### Additional Topics
- Insecure IPC (exported components, pending intent vulnerabilities)
- Root/emulator detection bypass techniques
- Debug logging exposure in release builds
- Insecure WebView configuration (JavaScript bridges)
- Hardcoded secrets and API keys in code/resources

### CTF Challenge Creation
- Multi-tier difficulty challenges (beginner through advanced)
- Flag hiding using obfuscation, encryption, steganography, and native code
- Progressive challenge chains building on previous solutions
- Scoring systems and hint mechanisms

### Training Curriculum
- Structured modules aligned with OWASP Mobile Top 10
- Lab exercises with guided exploitation and remediation
- Assessment criteria and rubrics
- Instructor notes and solution guides

## Workflow

Follow this sequence when building any security lab:

### Step 1: Define Learning Objective
Identify the specific vulnerability, OWASP category, and target skill level. Write a clear learning outcome statement: "After completing this lab, the student will be able to [identify/exploit/remediate] [vulnerability] in [context]."

### Step 2: Design the Vulnerability
Choose a realistic scenario where the vulnerability naturally occurs. Design the app feature that contains the vulnerability. Plan the attack surface and exploitation path. Determine prerequisite knowledge.

### Step 3: Implement the Vulnerable App
Create the Android project with the safety controls listed above. Implement the realistic app feature with the intentional vulnerability. Add `// VULNERABILITY:` markers at each vulnerable code point. Add synthetic test data. Include the persistent warning banner UI.

### Step 4: Create the Exploitation Guide
Document the tools needed (adb, jadx, frida, mitmproxy, etc.). Write step-by-step exploitation instructions with expected outputs. Include screenshots or expected terminal output at each step. Explain what the vulnerability enables and its real-world impact (with references to public CVEs or disclosed bugs where applicable).

### Step 5: Create the Remediation Guide
Implement the secure version of the same feature in a parallel source set or separate module. Add `// FIX:` markers showing each remediation. Explain why the fix works and what security properties it provides. Reference official Android documentation and OWASP guidance.

### Step 6: Add Lab Validation
Create automated tests that verify:
- The vulnerability is present and exploitable in the vulnerable variant
- The fix correctly resolves the vulnerability in the secure variant
- The lab resets cleanly to its initial state

## Project Structure Convention

```
security-lab-[topic]/
  app/
    src/
      vulnerable/       # Vulnerable build variant
        java/...
      secure/           # Remediated build variant
        java/...
      main/             # Shared code (UI, models, navigation)
        java/...
  exploitation-guide/   # Step-by-step attack walkthrough
  lab-config/           # Emulator setup, network config, reset scripts
  build.gradle.kts      # Defines vulnerable/secure product flavors
  README.md             # Safety warnings, setup instructions, objectives
```

## References

- `references/lab-architecture.md` — Lab environment setup, isolation, project structure
- `references/storage-labs.md` — Data storage vulnerability labs
- `references/network-labs.md` — Network security vulnerability labs
- `references/crypto-labs.md` — Cryptography vulnerability labs
- `references/injection-labs.md` — Injection vulnerability labs
- `references/ctf-design.md` — CTF challenge design and flag mechanics
- `references/training-curriculum.md` — Full security training curriculum structure
