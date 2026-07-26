#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "== Homelab setup =="

# --- 1. Check Docker is available ---
if ! command -v docker &> /dev/null; then
  echo "Docker isn't installed. Install it first, e.g.:"
  echo "  curl -fsSL https://get.docker.com | sh"
  echo "  sudo usermod -aG docker \$USER   # then log out/in"
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "The 'docker compose' plugin isn't available. Install docker-compose-plugin and re-run."
  exit 1
fi

# --- 2. Create .env if it doesn't exist yet ---
if [ ! -f .env ]; then
  cp .env.example .env
  echo
  echo "Created .env from .env.example."
  echo "Edit it now to set MEDIA_PATH and a real COUCHDB_PASSWORD, then re-run this script."
  exit 0
fi

# Pull in the values so we can create matching folders below
set -a
source .env
set +a

if [ "${COUCHDB_PASSWORD:-changeme}" = "changeme" ]; then
  echo "COUCHDB_PASSWORD is still the default in .env — please set a real password before continuing."
  exit 1
fi

if [ -z "${MEDIA_PATH:-}" ] || [ ! -d "$MEDIA_PATH" ]; then
  echo "MEDIA_PATH in .env is not set or doesn't exist: '${MEDIA_PATH:-<empty>}'"
  echo "Create that folder or point MEDIA_PATH at your real media location, then re-run."
  exit 1
fi

# --- 3. Create persistent config/data folders ---
echo "Creating config/data directories..."
mkdir -p \
  config/jellyfin/config \
  config/jellyfin/cache \
  config/couchdb/data \
  config/beszel/beszel_data \
  config/beszel/beszel_socket \
  config/beszel/beszel_agent_data

# --- 4. Pull images and start everything ---
echo "Pulling images..."
docker compose pull

echo "Starting services..."
docker compose up -d

# --- 5. Report status ---
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
IP=${IP:-<pi-ip>}

echo
echo "Done. Current status:"
docker compose ps

echo
echo "Access things at:"
echo "  Jellyfin: http://${IP}:8096"
echo "  Beszel:   http://${IP}:8090"
echo "  CouchDB:  http://${IP}:5984/_utils"
echo

if [ -z "${BESZEL_TOKEN:-}" ] || [ -z "${BESZEL_KEY:-}" ]; then
  echo "NOTE: Beszel's agent isn't paired yet."
  echo "Visit the Beszel URL above, create an admin account, click 'Add System',"
  echo "use /beszel_socket/beszel.sock as the Host/IP, then copy the Token/Key it"
  echo "shows you into .env (BESZEL_TOKEN / BESZEL_KEY) and run:"
  echo "  docker compose up -d beszel-agent"
  echo
fi

echo "See README.md for Obsidian LiveSync plugin setup."