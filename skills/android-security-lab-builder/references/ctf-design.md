# CTF Challenge Design

> **DISCLAIMER**: CTF challenges built with this guide must be used exclusively in authorized, isolated environments for security education. All flags, keys, and data are synthetic. Never deploy CTF infrastructure on production networks or target real systems.

## Difficulty Tiers

Design challenges across four difficulty levels. Each tier builds on the skills from the previous one.

### Tier 1: Beginner (100-200 points)

Target audience: developers with no security background. Challenges require only `adb` and basic file inspection.

| Challenge | Vulnerability | Technique Required |
|-----------|--------------|-------------------|
| Plaintext Creds | SharedPreferences in cleartext | `adb shell run-as` or `adb backup` |
| Leaky Logs | Sensitive data in Logcat | `adb logcat` with grep |
| Open Door | Exported Activity without auth | `adb shell am start` with extras |
| Config Leak | API key in `strings.xml` or `BuildConfig` | APK unzip + grep |

Example beginner challenge structure:

```kotlin
// SECURITY LAB: CTF Challenge — Beginner
// Challenge: Find the admin password stored insecurely

class LoginActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // FLAG is stored in plaintext SharedPreferences after first launch
        val prefs = getSharedPreferences("app_config", Context.MODE_PRIVATE)
        if (!prefs.contains("setup_done")) {
            prefs.edit()
                .putString("admin_password", "FLAG{pl41nt3xt_pr3fs_4r3_n0t_s4f3}")
                .putBoolean("setup_done", true)
                .apply()
        }
    }
}
```

### Tier 2: Intermediate (300-500 points)

Requires APK decompilation (jadx), traffic interception (mitmproxy/Burp), or basic Frida scripting.

| Challenge | Vulnerability | Technique Required |
|-----------|--------------|-------------------|
| Weak Crypto | Hardcoded AES key | jadx decompilation + Python decryption |
| Broken Pin | Certificate pinning with bypass flaw | Frida to hook TrustManager |
| SQL Leak | SQL injection in Content Provider | Crafted `content://` URI via adb |
| Token Forge | Weak JWT with `HS256` + known secret | JWT decode + resign |

### Tier 3: Advanced (600-800 points)

Requires Frida hooking, native library analysis, multi-step attack chains, or reverse engineering.

| Challenge | Vulnerability | Technique Required |
|-----------|--------------|-------------------|
| Native Secret | Flag encrypted in `.so` via JNI | Ghidra/IDA on native lib + Frida |
| Race Window | TOCTOU in file permission check | Frida timing manipulation |
| Chain Attack | Combine exported Activity + SQLi + WebView | Multi-step exploit chain |
| Custom Crypto | Homebrew XOR cipher | Frequency analysis or known-plaintext |

### Tier 4: Expert (900-1000 points)

Requires deep reverse engineering, exploit development, or chaining multiple complex vulnerabilities.

| Challenge | Vulnerability | Technique Required |
|-----------|--------------|-------------------|
| Kernel of Truth | Flag derived from device-specific Keystore interaction | Frida + Keystore API hooking |
| Steganography | Flag hidden in image pixel LSBs | Custom extraction script |
| Anti-Debug | Flag only visible when debugger detection is bypassed | Patch or Frida bypass |
| Protocol RE | Custom binary protocol over raw sockets | Wireshark + protocol reconstruction |

---

## Flag Format and Hiding Techniques

### Standard Flag Format

Use a consistent, recognizable flag format across all challenges:

```
FLAG{descriptive_snake_case_hint}
```

Examples:
- `FLAG{pl41nt3xt_pr3fs_4r3_n0t_s4f3}` (storage lab)
- `FLAG{tru5t_all_c3rts_tru5t_n0_on3}` (network lab)
- `FLAG{3cb_p3ngu1n_r3v34ls_p4tt3rns}` (crypto lab)
- `FLAG{un10n_s3l3ct_fl4g_fr0m_s3cr3ts}` (injection lab)

### Flag Hiding Methods

**Level 1 — Plaintext Storage** (Beginner): Store the flag directly in SharedPreferences, SQLite, Logcat, or resource files.

```kotlin
// Flag in SharedPreferences
prefs.edit().putString("secret", "FLAG{...}").apply()

// Flag in SQLite
db.execSQL("INSERT INTO secrets VALUES ('FLAG{...}')")

// Flag in string resources
// res/values/strings.xml: <string name="debug_key">FLAG{...}</string>
```

**Level 2 — Obfuscation** (Intermediate): Encode the flag with reversible transforms.

```kotlin
// Flag encoded as Base64 in BuildConfig
// buildConfigField("String", "HIDDEN", "\"RkxBR3tiNHNlNjRfMXNfbjB0X2VuY3J5cHQxMG59\"")

// Flag split across multiple string constants
private val part1 = "FLAG{spl1t_"
private val part2 = "str1ngs_"
private val part3 = "4r3_w34k}"
fun getFlag() = part1 + part2 + part3
```

**Level 3 — Encryption** (Advanced): Encrypt the flag with a key the participant must discover.

```kotlin
// Flag encrypted with a hardcoded key (participant must find the key first)
val encryptedFlag = byteArrayOf(0x4a, 0x2f, ...) // AES-CBC encrypted
// Key is the MD5 of another discovered value
```

**Level 4 — Native Code** (Expert): Hide the flag in a compiled native library.

```c
// In a .so file compiled via NDK:
// SECURITY LAB: CTF flag hidden in native code
JNIEXPORT jstring JNICALL
Java_com_securitylab_ctf_NativeLib_getFlag(JNIEnv *env, jobject thiz) {
    // XOR-encoded flag — requires reverse engineering the .so to recover
    char encoded[] = {0x17, 0x1d, 0x10, 0x16, 0x48, ...};
    char key = 0x51;
    for (int i = 0; i < sizeof(encoded); i++) {
        encoded[i] ^= key;
    }
    return (*env)->NewStringUTF(env, encoded);
}
```

**Level 5 — Steganography** (Expert): Embed the flag in image pixel data.

```kotlin
// Flag hidden in the least significant bits of a PNG in assets/
// Extraction requires reading pixel values and reconstructing the bitstream
fun hideInImage(bitmap: Bitmap, flag: String): Bitmap {
    val bits = flag.toByteArray().flatMap { byte ->
        (7 downTo 0).map { (byte.toInt() shr it) and 1 }
    }
    // Embed each bit in the LSB of the red channel of successive pixels
    // ... (extraction is the challenge)
}
```

---

## Scoring System

### Point Distribution

```
Total points available:  5000
Beginner challenges:     4 x 150 avg  =  600  (12%)
Intermediate challenges: 4 x 400 avg  = 1600  (32%)
Advanced challenges:     4 x 700 avg  = 2800  (56%) — includes expert
```

### Hint System

Each challenge offers up to three hints at a point cost:

| Hint Level | Cost | Content |
|-----------|------|---------|
| Hint 1 | -10% of challenge points | General direction (e.g., "Look at how data is stored") |
| Hint 2 | -25% of challenge points | Specific tool or technique (e.g., "Use `adb backup`") |
| Hint 3 | -50% of challenge points | Detailed walkthrough missing only the final step |

### Time Bonuses

Award bonus points for fast solves to encourage efficiency:

```
First solve:          +20% bonus
Within first hour:    +10% bonus
Within first 3 hours: +5% bonus
```

---

## Challenge Packaging

### Standard Challenge Structure

```
ctf-challenge-[name]/
  challenge/
    app-challenge.apk          # The vulnerable APK
    challenge-server/          # Optional backend (Docker)
    README.md                  # Brief description, setup, rules
  solution/
    WRITEUP.md                 # Full solution guide (instructor only)
    exploit-scripts/           # Automated exploitation scripts
    flags.json                 # All flags and their point values
  hints/
    hint1.txt                  # Progressive hints
    hint2.txt
    hint3.txt
```

### Flag Submission and Validation

```kotlin
// lab-config/src/main/kotlin/lab/ctf/FlagValidator.kt
// SECURITY LAB: CTF flag validation server

object FlagValidator {
    // Flags stored as salted SHA-256 hashes — participants cannot reverse them
    private val flagHashes = mapOf(
        "challenge_01" to "a3f2b8c9d1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9",
        "challenge_02" to "b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4",
    )

    fun validate(challengeId: String, submittedFlag: String): Boolean {
        val expected = flagHashes[challengeId] ?: return false
        val submitted = hashFlag(submittedFlag)
        return MessageDigest.isEqual(expected.toByteArray(), submitted.toByteArray())
    }

    private fun hashFlag(flag: String): String {
        val salt = "ctf-lab-salt-2024"  // Per-competition salt
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest("$salt:$flag".toByteArray())
            .joinToString("") { "%02x".format(it) }
    }
}
```

---

## Challenge Design Checklist

Before deploying any CTF challenge in a lab environment:

- [ ] Flag uses the standard `FLAG{...}` format
- [ ] Challenge APK includes `android:testOnly="true"` and the `.vulnerable.lab` applicationId suffix
- [ ] All data is synthetic (fake names, test card numbers, placeholder keys)
- [ ] Challenge is solvable without internet access (all resources are local)
- [ ] Solution writeup is complete and tested by someone other than the author
- [ ] Hints are progressive (general to specific) and priced appropriately
- [ ] Challenge server (if any) binds only to `127.0.0.1`
- [ ] Reset script returns the challenge to its initial state
- [ ] Difficulty rating is validated by at least one tester at the target skill level
