#!/usr/bin/env bash
# ==============================================================================
# Pingo AWS Lightsail Automated Server Provisioning Script
# ==============================================================================
set -euo pipefail

echo "========================================================"
echo "🚀 Starting Pingo Production Setup on AWS Lightsail"
echo "========================================================"

# 1. Update Ubuntu packages
echo "📦 Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl git ufw apt-transport-https ca-certificates gnupg lsb-release

# 2. Install Docker & Docker Compose
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker "$USER"
fi

# 3. Enable Docker systemd service
sudo systemctl enable docker
sudo systemctl start docker

# 4. Configure Basic UFW Firewall
echo "🛡️ Configuring Firewall..."
sudo ufw allow 22/tcp || true
sudo ufw allow 80/tcp || true
sudo ufw allow 443/tcp || true
sudo ufw --force enable || true

echo "========================================================"
echo "✅ Server dependencies installed successfully!"
echo "👉 If running for the first time, log out and log back in,"
echo "   or run: newgrp docker"
echo "========================================================"

