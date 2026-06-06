#!/usr/bin/env bash
# Deploy a specific image tag to production.
# Usage: ./scripts/deploy.sh <image-tag>
# Example: ./scripts/deploy.sh sha-a1b2c3d

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
COMPOSE_FILE="compose.prod.yml"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASES_FILE="${DEPLOY_DIR}/.releases"
MAX_RELEASES=5

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# ── Validate input ────────────────────────────────────────────────────────────
[[ $# -eq 1 ]] || die "Usage: $0 <image-tag>"
IMAGE_TAG="$1"

# Guard against shell injection: tag must be alphanumeric + dash/dot
[[ "$IMAGE_TAG" =~ ^[a-zA-Z0-9._-]+$ ]] || die "Invalid image tag: $IMAGE_TAG"

cd "$DEPLOY_DIR"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
log "Deploying tag: $IMAGE_TAG"

command -v docker >/dev/null 2>&1 || die "docker is not installed"
[[ -f "$COMPOSE_FILE" ]]          || die "$COMPOSE_FILE not found"
[[ -f ".env" ]]                   || die ".env not found — copy .env.example and fill in values"

# ── Pull new images ───────────────────────────────────────────────────────────
log "Pulling images..."
IMAGE_TAG="$IMAGE_TAG" docker compose -f "$COMPOSE_FILE" pull backend frontend

# ── Save current tag as previous release (for rollback) ───────────────────────
current_tag=""
if [[ -f "$RELEASES_FILE" ]]; then
  current_tag=$(tail -n 1 "$RELEASES_FILE" || true)
fi

# ── Bring up new stack ────────────────────────────────────────────────────────
log "Starting services..."
IMAGE_TAG="$IMAGE_TAG" docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# ── Health check ──────────────────────────────────────────────────────────────
log "Waiting for services to be healthy..."
max_wait=60
elapsed=0
interval=5

until docker compose -f "$COMPOSE_FILE" ps --format json \
    | grep -v '"Health":"healthy"' \
    | grep -q '"Health"' 2>/dev/null && false || \
    docker compose -f "$COMPOSE_FILE" ps | grep -qv "unhealthy"; do
  if [[ $elapsed -ge $max_wait ]]; then
    die "Services failed health check after ${max_wait}s — rolling back"
  fi
  sleep $interval
  elapsed=$((elapsed + interval))
done

# ── Record successful release ─────────────────────────────────────────────────
echo "$IMAGE_TAG" >> "$RELEASES_FILE"

# Keep only the last MAX_RELEASES entries
if [[ -f "$RELEASES_FILE" ]]; then
  tail -n "$MAX_RELEASES" "$RELEASES_FILE" > "${RELEASES_FILE}.tmp"
  mv "${RELEASES_FILE}.tmp" "$RELEASES_FILE"
fi

log "Deploy complete. Tag '$IMAGE_TAG' is live."
[[ -n "$current_tag" ]] && log "Previous release was '$current_tag' — run ./scripts/rollback.sh to revert."
