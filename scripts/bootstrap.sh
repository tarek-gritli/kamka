#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu/Debian host for running the kamka stack.
# Safe to run multiple times (idempotent).
# Usage: sudo ./scripts/bootstrap.sh

set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"

# ── System update ─────────────────────────────────────────────────────────────
log "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# ── Install Docker ────────────────────────────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
else
  log "Installing Docker..."
  apt-get install -y -qq ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  log "Docker installed: $(docker --version)"
fi

# ── Add deploy user to docker group ──────────────────────────────────────────
DEPLOY_USER="${SUDO_USER:-ubuntu}"
if id "$DEPLOY_USER" &>/dev/null; then
  usermod -aG docker "$DEPLOY_USER"
  log "Added $DEPLOY_USER to docker group"
fi

# ── Create app directory ──────────────────────────────────────────────────────
APP_DIR="/opt/kamka"
if [[ ! -d "$APP_DIR" ]]; then
  mkdir -p "$APP_DIR"
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "$APP_DIR"
  log "Created app directory: $APP_DIR"
fi

# ── Open firewall ports (ufw) ─────────────────────────────────────────────────
if command -v ufw >/dev/null 2>&1; then
  log "Configuring firewall..."
  ufw allow 22/tcp   comment "SSH"
  ufw allow 80/tcp   comment "HTTP"
  ufw allow 443/tcp  comment "HTTPS"
  ufw allow 3001/tcp comment "Uptime Kuma"
  ufw --force enable
  log "Firewall configured"
fi

# ── Install git ───────────────────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  apt-get install -y -qq git
  log "Git installed: $(git --version)"
fi

log "Bootstrap complete. Log out and back in for docker group to take effect."
log "Next: cd $APP_DIR && git clone <repo> . && cp .env.example .env && nano .env"
