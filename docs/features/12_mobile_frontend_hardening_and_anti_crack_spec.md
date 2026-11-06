# Specification: Pingo Mobile Frontend Hardening & Anti-Crack Security Architecture

## 1. Executive Summary & Purpose
This document establishes the military-grade, defense-in-depth mobile frontend hardening standards for Pingo (Android & iOS). Its objective is to ensure that:
1. The app cannot be decompiled, reverse-engineered, or patched by crackers.
2. Runtime memory cannot be hooked or manipulated using dynamic analysis frameworks (Frida, Xposed, Objection).
3. Encryption keys never exist in plaintext in memory or on flash storage.
4. Man-in-the-Middle (MITM) network interception is completely blocked.
5. Malware, spyware, and screen recorders cannot capture document vault previews, passwords, or personal reminders.

---

## 2. Threat Modeling & Attack Vectors

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MOBILE ATTACK SURFACES                         │
├──────────────────────────┬─────────────────────────┬───────────────────┤
│ 1. Static Decompilation  │ 2. Dynamic Memory Hook  │ 3. Network Proxy  │
│ (JADX, Ghidra, Apktool)  │ (Frida, Xposed, GDB)    │ (Burp, Charles)   │
├──────────────────────────┼─────────────────────────┼───────────────────┤
│ 4. OS Compromise         │ 5. Screen Snooping      │ 6. Repackaging    │
│ (Root, Magisk, Jailbreak)│ (Malware, Recorders)    │ (Cracked Clones)  │
└──────────────────────────┴─────────────────────────┴───────────────────┘
```

---

## 3. Defense-in-Depth: The 7 Security Pillars

### Pillar 1: Hardware-Backed Key Storage (Keystore & Secure Enclave)
- **Mechanism**: Never store master keys or database encryption keys in `SharedPreferences`, `NSUserDefaults`, or unencrypted local files.
- **Implementation**:
  - Android: **Android Keystore Provider** utilizing Hardware Security Module (HSM) / Trusted Execution Environment (TEE) / StrongBox.
  - iOS: **Keychain Services** backed by the Apple **Secure Enclave processor**.
- **Flutter Package**: `flutter_secure_storage` configured with:
  - `encryptedSharedPreferences: true` (Android)
  - `kSecAccessControlBiometryAny` / `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (iOS).

### Pillar 2: Screen Snooping & Spyware Prevention (`FLAG_SECURE`)
- **Mechanism**: Prevent malware, accessibility services, and screenshot capture from reading open documents or reminders.
- **Implementation**:
  - **Android (`MainActivity.kt`)**:
    ```kotlin
    import android.view.WindowManager
    import io.flutter.embedding.android.FlutterActivity
    import io.flutter.embedding.engine.FlutterEngine

    class MainActivity: FlutterActivity() {
        override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
            super.configureFlutterEngine(flutterEngine)
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
    ```
  - **iOS (`AppDelegate.swift`)**: Add a privacy blur overlay when the application transitions to background / app switcher.

### Pillar 3: SSL / TLS Certificate Pinning (Anti-MITM)
- **Mechanism**: Ensure the mobile app only communicates with the authentic Pingo cloud server and rejects any proxy certificates (Burp Suite, Charles Proxy).
- **Implementation**:
  - Pin the public key SHA-256 fingerprint in the networking client (`Dio` / `HttpOverrides`):
    ```dart
    final securityContext = SecurityContext(withTrustedRoots: false);
    // Pin certificate SPKI SHA-256 hash
    ```
  - Network Security Config on Android (`res/xml/network_security_config.xml`):
    ```xml
    <network-security-config>
        <domain-config cleartextTrafficPermitted="false">
            <domain includeSubdomains="true">api.pingo.app</domain>
            <pin-set expiration="2027-01-01">
                <pin digest="SHA-256">YOUR_SERVER_PUBLIC_KEY_HASH=</pin>
            </pin-set>
        </domain-config>
    </network-security-config>
    ```

### Pillar 4: Root, Jailbreak & Emulator Detection
- **Mechanism**: Detect compromised execution environments where an attacker has arbitrary kernel and memory access.
- **Detection Checks**:
  1. Presence of `su` binary in `/system/bin`, `/system/xbin`, `/sbin`, `/vendor/bin`.
  2. Known root management packages: `com.topjohnwu.magisk`, `eu.chainfire.supersu`, `io.github.vvb2060.magisk`.
  3. KernelSU `/data/adb/ksu` presence.
  4. iOS Cydia / Sileo files (`/Applications/Cydia.app`, `/bin/sh`, `/usr/sbin/sshd`).
  5. Read-write permissions on `/system`.
- **Action**: Immediately wipe ephemeral keys from memory, lock the vault, and alert the user.

### Pillar 5: Dynamic Hooking & Debugger Detection (Anti-Frida & Anti-Xposed)
- **Mechanism**: Detect if Frida server or a debugger is attached to intercept method return values (e.g. bypassing PIN authentication).
- **Checks**:
  - Check `ptrace(PTRACE_TRACEME, ...)` — returns -1 if a debugger is already attached.
  - Scan `/proc/self/maps` for `frida-agent.so`, `gadget.so`, `xposed`.
  - Check default Frida port `27042` and open socket handles.
  - Terminate app execution immediately upon detection (`exit(0)`).

### Pillar 6: Code Obfuscation & Symbol Stripping
- **Mechanism**: Make decompiled smali / DEX bytecode and Dart assembly unreadable.
- **Flutter Release Command**:
  ```bash
  flutter build apk --release \
    --obfuscate \
    --split-debug-info=./build/app/outputs/symbols
  ```
- **Android R8 / ProGuard (`android/app/proguard-rules.pro`)**:
  ```proguard
  # Obfuscate classes, methods, and variables to a, b, c
  -repackageclasses 'pingo.hidden'
  -allowaccessmodification
  -optimizationpasses 5
  -dontusemixedcaseclassnames
  -dontskipnonpubliclibraryclasses
  -verbose
  ```

### Pillar 7: Anti-Repackaging & App Signature Verification
- **Mechanism**: Prevent crackers from modifying the APK, re-signing it with their own key, and distributing a cracked version.
- **Implementation**:
  - Verify the signing certificate SHA-256 fingerprint at runtime against the official production signing key:
    ```kotlin
    val signatures = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
    // Hash signature and compare against official hardcoded sha256
    ```
  - If the hash differs, the app is a tampered clone; erase local cache and terminate.

---

## 4. Implementation Phasing Strategy (Future Roadmap)

| Phase | Focus Area | Deliverables |
| :--- | :--- | :--- |
| **Phase 1: Zero-Friction Baseline** | Storage & Screen | `flutter_secure_storage` Keystore integration + `FLAG_SECURE` screen protection |
| **Phase 2: Network Transport Guard** | Network & API | SSL Public Key Pinning on Dio client + Android Network Security Config |
| **Phase 3: Runtime Tamper Shield** | Device Environment | Root, Jailbreak & Frida dynamic hooking detection |
| **Phase 4: Release Hardening** | Binary Integrity | Flutter code obfuscation + ProGuard R8 rules + Signature verification |

---

## 5. Summary Check before Production Release
- [ ] `FLAG_SECURE` enabled on Android & iOS screen blur enabled.
- [ ] No hardcoded API keys, passwords, or encryption salts in Dart code.
- [ ] SSL Pinning active with backup pin for certificate rotation.
- [ ] Release build compiled with `--obfuscate` and symbols stored in secure internal storage.
- [ ] Root / Jailbreak check active on critical Vault access points.
