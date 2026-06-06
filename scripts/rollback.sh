#!/usr/bin/env bash
# Roll back to the previous successful release.
# Usage: ./scripts/rollback.sh
#        ./scripts/rollback.sh <specific-tag>   # roll back to a specific tag

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
COMPOSE_FILE="compose.prod.yml"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASES_FILE="${DEPLOY_DIR}/.releases"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

cd "$DEPLOY_DIR"

# ── Determine rollback target ─────────────────────────────────────────────────
if [[ $# -eq 1 ]]; then
  TARGET_TAG="$1"
  [[ "$TARGET_TAG" =~ ^[a-zA-Z0-9._-]+$ ]] || die "Invalid tag: $TARGET_TAG"
else
  [[ -f "$RELEASES_FILE" ]] || die "No release history found at $RELEASES_FILE"
  line_count=$(wc -l < "$RELEASES_FILE")
  [[ $line_count -ge 2 ]] || die "Only one release recorded — nothing to roll back to"
  # Second-to-last line is the previous release
  TARGET_TAG=$(tail -n 2 "$RELEASES_FILE" | head -n 1)
fi

log "Rolling back to tag: $TARGET_TAG"

# ── Deploy previous tag ───────────────────────────────────────────────────────
IMAGE_TAG="$TARGET_TAG" docker compose -f "$COMPOSE_FILE" pull backend frontend
IMAGE_TAG="$TARGET_TAG" docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# ── Remove the failed release from history ────────────────────────────────────
if [[ -f "$RELEASES_FILE" ]]; then
  head -n -1 "$RELEASES_FILE" > "${RELEASES_FILE}.tmp"
  mv "${RELEASES_FILE}.tmp" "$RELEASES_FILE"
fi

log "Rollback complete. Tag '$TARGET_TAG' is live."
