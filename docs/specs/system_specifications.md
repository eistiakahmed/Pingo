# Pingo System Specifications & Non-Functional Requirements

## 1. Non-Functional Requirements (NFR)

| Area | Requirement | Target |
| :--- | :--- | :--- |
| **Notification Reliability** | Reminders delivered at the exact second configured | **>= 99.0%** across tested Android & iOS devices |
| **Time-to-Capture** | Median time from app launch to saved reminder (Voice or Text) | **< 5 seconds** |
| **NLP Accuracy** | Accurate extraction of date, time, title, and recurrence | **>= 90% (English)**, **>= 85% (Bangla / Banglish)** |
| **Offline Operability** | Core reminder creation, alarms, and vault access without network | **100% functional offline** |
| **Vault Encryption** | Cryptographic security for stored documents and metadata | **AES-256 (GCM mode)** with keys in OS Keystore / Keychain |
| **Crash-Free Sessions** | Stability across user sessions in production | **>= 99.5%** |

## 2. Platform Specific Guidelines

### 2.1 Android (8.0+ / API 26+)
- **Exact Alarms (`SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`)**: Mandated for punctual alerts on Android 12+.
- **Boot Persistence (`RECEIVE_BOOT_COMPLETED`)**: Reschedules all active alarms immediately upon phone restart.
- **Battery Optimization Bypass**: Interactive onboarding screen guiding users to exclude Pingo from aggressive background killing (Xiaomi MIUI/HyperOS, Samsung OneUI, Oppo ColorOS).
- **Notification Channels**: Distinct channels for *Urgent Reminders*, *Standard Reminders*, and *Daily Digest*.

### 2.2 iOS (iOS 14+)
- **Local Notifications Queue**: OS limits pending notifications to 64. Pingo prioritizes the nearest 60 active alerts and replenishes upon app resume or background refresh.
- **Time-Sensitive Alerts**: Configured for high-priority medicine or critical deadline reminders.
