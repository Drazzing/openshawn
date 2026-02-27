#!/usr/bin/env bash
# Start OpenClaw gateway with hardened Docker Compose (this repo).
# Run from repo root. Image is built from the OpenClaw repo (set OPENCLAW_REPO to rebuild).
# Usage: ./scripts/docker-start-secure.sh
#        REBUILD=1 ./scripts/docker-start-secure.sh   # build from OPENCLAW_REPO first

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
COMPOSE_FILE="docker-compose.secure.yml"

if [[ ! -f .env ]]; then
  if [[ -f .env.secure ]]; then
    cp .env.secure .env
    echo "Created .env from .env.secure."
    echo "Edit .env and set OPENCLAW_GATEWAY_TOKEN (replace CHANGE_ME_...) and any API keys, then run:"
    echo "  ./scripts/docker-start-secure.sh"
    exit 1
  fi
  echo ".env not found. Copy .env.secure to .env and set OPENCLAW_GATEWAY_TOKEN." >&2
  exit 1
fi
set -a && source .env && set +a

OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
export OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE_DIR
# Ensure gateway config exists (skills + allowInsecureAuth for token-only UI)
CONFIG_JSON="${OPENCLAW_CONFIG_DIR}/openclaw.json"
CONFIG_TEMPLATE="${ROOT_DIR}/openclaw.secure.json"
DEVELOPER_CONFIG="${ROOT_DIR}/openclaw.developer.json"
DATA_DIR="${ROOT_DIR}/data"
# If using repo data dir and developer config exists, use it so Claw picks up best config for developers
if [[ -f "$DEVELOPER_CONFIG" ]]; then
  CONFIG_DIR_RESOLVED="$(cd "$OPENCLAW_CONFIG_DIR" 2>/dev/null && pwd)" || true
  DATA_DIR_RESOLVED="$(cd "$DATA_DIR" 2>/dev/null && pwd)" || true
  if [[ -n "${CONFIG_DIR_RESOLVED:-}" && -n "${DATA_DIR_RESOLVED:-}" && "$CONFIG_DIR_RESOLVED" = "$DATA_DIR_RESOLVED" ]]; then
    cp "$DEVELOPER_CONFIG" "$CONFIG_JSON"
    echo "Using developer config (openclaw.developer.json) for Claw."
  elif [[ ! -f "$CONFIG_JSON" && -f "$CONFIG_TEMPLATE" ]]; then
    cp "$CONFIG_TEMPLATE" "$CONFIG_JSON"
    echo "Created $CONFIG_JSON from openclaw.secure.json (skills + token-only UI)."
  fi
elif [[ ! -f "$CONFIG_JSON" && -f "$CONFIG_TEMPLATE" ]]; then
  cp "$CONFIG_TEMPLATE" "$CONFIG_JSON"
  echo "Created $CONFIG_JSON from openclaw.secure.json (skills + token-only UI)."
fi
IMAGE_NAME="${OPENCLAW_IMAGE:-openclaw:local}"

# Default OPENCLAW_REPO to sibling openclaw directory so compose build context works
OPENCLAW_REPO="${OPENCLAW_REPO:-$(dirname "$ROOT_DIR")/openclaw}"
export OPENCLAW_REPO

TOKEN_PLACEHOLDER="CHANGE_ME_GENERATE_A_STRONG_TOKEN"
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" || "$OPENCLAW_GATEWAY_TOKEN" = "$TOKEN_PLACEHOLDER" ]]; then
  echo "OPENCLAW_GATEWAY_TOKEN not set or still placeholder. Edit .env and set it to a strong random value (e.g. 32+ hex chars), then run:" >&2
  echo "  ./scripts/docker-start-secure.sh" >&2
  exit 1
fi

# Build image if missing or REBUILD=1
IMAGE_EXISTS=0
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
  IMAGE_EXISTS=1
fi
if [[ $IMAGE_EXISTS -eq 0 || "${REBUILD:-0}" = "1" ]]; then
  if [[ ! -d "$OPENCLAW_REPO" ]]; then
    echo "OPENCLAW_REPO path not found: $OPENCLAW_REPO" >&2
    echo "Set OPENCLAW_REPO in .env to your OpenClaw source repo (e.g. /path/to/openclaw)." >&2
    exit 1
  fi
  echo "==> Building image from OpenClaw repo: $OPENCLAW_REPO"
  docker compose -f "$COMPOSE_FILE" build openclaw-gateway
fi

echo "==> Stopping existing containers"
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true

echo "==> Starting OpenClaw gateway"
docker compose -f "$COMPOSE_FILE" up -d openclaw-gateway

echo ""
echo "Gateway is running. Dashboard: http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/"
echo "Token: $OPENCLAW_GATEWAY_TOKEN"
echo "  logs: docker compose -f $COMPOSE_FILE logs -f openclaw-gateway"
echo "  stop: docker compose -f $COMPOSE_FILE down"
