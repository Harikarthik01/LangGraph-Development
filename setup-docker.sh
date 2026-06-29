#!/usr/bin/env bash
# Run once on a fresh Ubuntu 22.04 Lightsail instance.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Docker's official repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Run docker without sudo (log out/in after this)
sudo usermod -aG docker "$USER"

echo "Docker installed. Log out and back in, then run: docker --version"
