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
  config/couchdb/data

# Ensure local.ini exists as a real file, not a directory
# If it's missing, Docker's bind mount auto-creates it as a directory instead of a
# file, which crashes CouchDB on startup (eisdir). Self-heal that here.
LOCAL_INI="config/couchdb/local.ini"
if [ -d "$LOCAL_INI" ]; then
  echo "Found $LOCAL_INI as a directory (leftover from a bad bind mount) — removing it."
  rmdir "$LOCAL_INI" 2>/dev/null || rm -rf "$LOCAL_INI"
fi
if [ ! -f "$LOCAL_INI" ]; then
  echo "Creating $LOCAL_INI..."
  cat > "$LOCAL_INI" << 'EOF'
[couchdb]
single_node = true
max_document_size = 50000000

[chttpd]
require_valid_user = true
max_http_request_size = 4294967296

[chttpd_auth]
require_valid_user = true
authentication_redirect = /_utils/session.html

[httpd]
WWW-Authenticate = Basic realm="couchdb"
enable_cors = true

[cors]
origins = app://obsidian.md, capacitor://localhost, http://localhost
credentials = true
headers = accept, authorization, content-type, origin, referer
methods = GET, PUT, POST, HEAD, DELETE
max_age = 3600
EOF
fi

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
echo "  CouchDB:  http://${IP}:5984/_utils"
echo
echo "See README.md for Obsidian LiveSync plugin setup, and TAILSCALE.md for remote access."