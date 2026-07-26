# Homelab

Docker Compose stack for a Raspberry Pi: Jellyfin, an Obsidian LiveSync backend (CouchDB), and Netdata for monitoring.

## First-time setup

```bash
git clone <this repo> homelab
cd homelab
cp .env.example .env
nano .env   # set MEDIA_PATH to where your media actually lives, set a real COUCHDB_PASSWORD
mkdir -p config/jellyfin/config config/jellyfin/cache config/couchdb/data
docker compose up -d
```

Check it's running:

```bash
docker compose ps
docker compose logs -f jellyfin
```

## Accessing things

- **Jellyfin**: `http://<pi-ip>:8096`
- **Netdata**: `http://<pi-ip>:19999`
- **CouchDB**: `http://<pi-ip>:5984/_utils` (Fauxton admin UI, log in with your `.env` creds)

## Setting up Obsidian LiveSync

1. Install the "Self-hosted LiveSync" plugin in Obsidian.
2. In the plugin settings, set the remote database URI to `http://<pi-ip>:5984/<some-db-name>`.
3. Enter the username/password from your `.env`.
4. Enable it, and do the same on your other devices pointing at the same URI.

The CORS/auth settings CouchDB needs for the plugin to talk to it are already baked into `config/couchdb/local.ini` — you shouldn't need to touch that unless something changes upstream.

## Adding/removing services later

This is the whole point of doing it this way — each service is an isolated block in `docker-compose.yml`. To add something:

1. Add a new service block (copy the shape of an existing one).
2. Add any new folders it needs under `config/`.
3. Add any new variables it needs to `.env.example` and your real `.env`.
4. `docker compose up -d` — only the new/changed services restart, everything else keeps running.

To remove something, delete its block and run `docker compose up -d` again (add `docker compose down <service>` first if you want it stopped immediately), then clean up its config folder if you don't need the data anymore.

## TODOs

- **Jellyfin hardware transcoding** on a Pi is possible (V4L2 M2M / VideoCore) but fiddly — this compose file runs Jellyfin CPU-only to start. Worth tackling once the basics are working.
- **`network_mode: host`** is used for Jellyfin (device discovery) and Netdata (accurate host stats). This means their ports aren't remapped through Compose — they use whatever port the app itself listens on. If you want isolation instead, drop `network_mode: host` and add an explicit `ports:` mapping per service.
- back up `config/couchdb/data` and `config/jellyfin/config`