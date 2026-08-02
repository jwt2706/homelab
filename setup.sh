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
  config/dnsmasq \
  config/caddy/data \
  config/caddy/config

# --- 3b. Ensure local.ini exists as a real file, not a directory ---
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

# --- 3c. Detect Tailscale IP and (re)generate dnsmasq.conf ---
# Needed so *.home resolves to the right IP across your tailnet. Regenerated
# every run in case the Tailscale IP ever changes.
if [ -z "${TAILSCALE_IP:-}" ]; then
  if command -v tailscale &> /dev/null; then
    DETECTED_IP=$(tailscale ip -4 2>/dev/null || true)
    if [ -n "$DETECTED_IP" ]; then
      echo "TAILSCALE_IP=$DETECTED_IP" >> .env
      TAILSCALE_IP="$DETECTED_IP"
      echo "Detected Tailscale IP ($DETECTED_IP) and saved it to .env."
    fi
  fi
fi

if [ -z "${TAILSCALE_IP:-}" ]; then
  echo "Couldn't detect a Tailscale IP — is Tailscale installed and connected? See README.md."
  echo "Alternatively, set TAILSCALE_IP manually in .env, then re-run this script."
  exit 1
fi

cat > config/dnsmasq/dnsmasq.conf << EOF
no-resolv
no-hosts
address=/home/${TAILSCALE_IP}
EOF

# --- 3d. Warn if something's already bound to port 53 (commonly systemd-resolved) ---
if command -v ss &> /dev/null; then
  EXISTING_53=$(ss -tulnp 2>/dev/null | grep ':53 ' || true)
  if [ -n "$EXISTING_53" ] && ! echo "$EXISTING_53" | grep -qi docker; then
    echo
    echo "WARNING: something is already listening on port 53 (often systemd-resolved's"
    echo "stub listener). This will conflict with the dnsmasq container. If dnsmasq fails"
    echo "to start, see README.md for how to free up port 53."
    echo
  fi
fi

# --- 3e. Ensure Caddyfile exists as a real file, not a directory ---
# Same class of bug as local.ini above: if missing, Docker's bind mount would
# auto-create it as a directory, and Caddy fails to even start.
CADDYFILE="config/caddy/Caddyfile"
if [ -d "$CADDYFILE" ]; then
  echo "Found $CADDYFILE as a directory (leftover from a bad bind mount) — removing it."
  rmdir "$CADDYFILE" 2>/dev/null || rm -rf "$CADDYFILE"
fi
if [ ! -f "$CADDYFILE" ]; then
  echo "Creating $CADDYFILE..."
  cat > "$CADDYFILE" << 'EOF'
# Plain HTTP — everything here only lives on your tailnet anyway, no public
# exposure, so no cert to manage.

http://jellyfin.home {
	reverse_proxy localhost:8096
}

http://couchdb.home {
	reverse_proxy localhost:5984
}

http://glances.home {
	reverse_proxy localhost:61208
}
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
echo "  Jellyfin: http://${IP}:8096   (or http://jellyfin.home once Split DNS is set up)"
echo "  CouchDB:  http://${IP}:5984/_utils   (or http://couchdb.home)"
echo "  Glances:  http://${IP}:61208   (or http://glances.home)"