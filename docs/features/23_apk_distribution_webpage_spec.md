# Feature Specification: Public APK Web Distribution Portal & Production Deployment

**Document ID**: `docs/features/23_apk_distribution_webpage_spec.md`  
**Status**: APPROVED / IMPLEMENTATION  
**Primary Architect**: Principal System Architect & Staff Full-Stack Engineer  
**Security Tier**: Public Asset Delivery / High Availability  

---

## 1. Problem Statement & Motivation

During mobile testing, local network barriers (e.g. Android devices operating on separate Wi-Fi subnets, mobile 4G/5G data, or strict NAT firewalls) prevent testers from downloading the Flutter release APK directly from a local workstation developer server (`http://192.168.x.x:8080`). Furthermore, local port conflicts (such as Python `http.server` raising `OSError: [Errno 98] Address already in use`) add friction to mobile testing and installation.

### Architectural Solution
Provide a hardened, public download endpoint directly hosted on the production AWS infrastructure (`http://98.84.163.177/download`):
1. **Responsive Executive Web Landing Page**: Clean, professional, dark-mode landing page styled to match Pingo brand guidelines (zero cartoon icons/emojis, executive monogram, version and file size indicators).
2. **High-Throughput Binary Streaming**: FastAPI `FileResponse` configured with MIME type `application/vnd.android.package-archive` and `Content-Disposition: attachment; filename=pingo-release.apk`.
3. **Containerized Volume Persistence**: Storage directory mounted into the `pingo-api` container or bundled within the application distribution.

---

## 2. API Contract & Routing Specifications

### 2.1 `GET /download` and `GET /download/`
- **Description**: Returns the responsive HTML landing page for one-click APK download.
- **Response Headers**: `Content-Type: text/html; charset=utf-8`
- **Status**: `200 OK`

### 2.2 `GET /download/app-release.apk`
- **Description**: Streams the production Flutter Android APK binary.
- **Response Headers**:
  - `Content-Type: application/vnd.android.package-archive`
  - `Content-Disposition: attachment; filename="pingo-release.apk"`
  - `Content-Length: ~57671680`
- **Status**: `200 OK` (or `404 Not Found` if binary not uploaded)

---

## 3. Implementation Plan

1. **Static HTML Asset**:
   - Copy and adjust `apps/mobile/build/app/outputs/flutter-apk/index.html` to `apps/server/app/static/download.html`.
   - Update target download link to absolute `/download/app-release.apk`.
2. **FastAPI Endpoints**:
   - In `apps/server/app/main.py`, mount `/download` and `/download/app-release.apk` routes.
3. **Deployment Workflow**:
   - Commit server updates to `develop` and `main`.
   - Transfer `app-release.apk` to AWS EC2 instance (`98.84.163.177`).
   - Pull latest git commits on EC2 and restart `api` container.
   - Verify public HTTP response codes and headers.
