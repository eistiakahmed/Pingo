# 15. AWS Lightsail Production Deployment Architecture & Guide

## Architecture Overview
This specification details the production deployment of the Pingo Backend on **AWS Lightsail**. With AWS Lightsail, the backend runs in an isolated, secure containerized environment with automated TLS/SSL encryption and predictable costs.

```
       [ Mobile Client (Flutter) / Web / External Requests ]
                                 │
                                 │ HTTPS (Port 443 with TLS 1.3)
                                 ▼
                    [ Caddy Reverse Proxy ]
               (Automatic Let's Encrypt / ZeroSSL)
                                 │
                                 │ Internal Docker Bridge
                                 ▼
                     [ Pingo API (FastAPI) ]
                       (Port 8000 Internal)
                                 │
                                 │ Private Internal Network
                                 ▼
                     [ PostgreSQL Database ]
                         (Port 5432 Internal)
```

---

## 1. AWS Lightsail Instance Specifications
- **Platform**: Linux/Unix
- **Blueprint**: OS Only &rarr; Ubuntu 24.04 LTS (or 22.04 LTS)
- **Instance Plan**: \$5/month (1 GB RAM, 1 vCPU, 40 GB SSD) or \$10/month (2 GB RAM, 2 vCPUs, 60 GB SSD - recommended for smooth multi-container builds)
- **Static IP**: Attached via Lightsail "Networking" tab to ensure IP persists across reboots.

---

## 2. Firewall & Security Boundaries
Lightsail firewall rules:
- **SSH (Port 22)**: Open for administration (restricted to your IP recommended).
- **HTTP (Port 80)**: Open for ACME HTTP-01 SSL certificate challenge.
- **HTTPS (Port 443)**: Open for encrypted mobile API traffic.
- **Database (Port 5432)**: **CLOSED** to the internet. Accessible only internally within the Docker bridge.

---

## 3. Production Docker Architecture (`docker-compose.prod.yml`)
The production stack consists of:
1. **`caddy`**: Handles automatic TLS certificate generation and renewal, terminates SSL, and proxies requests to `pingo-api`.
2. **`api`**: Production FastAPI application running non-root via Uvicorn.
3. **`db`**: Secure, password-protected PostgreSQL container with persisted volume.

---

## 4. Environment Variables & Secrets
Secrets must **never** be checked into git. On the Lightsail server, an `.env.prod` file will store:
- `POSTGRES_USER`: Dedicated database user
- `POSTGRES_PASSWORD`: Strong 32+ character random secret
- `DATABASE_URL`: Internal connection string
- `SECRET_KEY`: High-entropy 64-character token encryption secret
- `AI_PROVIDER`: `deepseek`
- `DEEPSEEK_API_KEY`: Runtime DeepSeek API key
- `DOMAIN_NAME`: Custom domain or server IP

