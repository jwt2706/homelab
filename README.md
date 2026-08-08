# homelab 🏡

this is a tiny self-hosted setup i made for a raspberry pi 4 model b (8gb). it runs jellyfin, an obsidian livesync couchdb backend, and a few little helper services so i can reach everything from anywhere over tailscale without making it complicated.

## what it includes

- **jellyfin** for media
- **couchdb** for obsidian livesync
- **dnsmasq + caddy** so stuff like `jellyfin.home` works instead of using raw ip:port
- **glances** for quick stats
- **tailscale** so it’s reachable from other devices without opening ports

## quick setup

```bash
git clone <this repo> homelab && cd homelab
cp .env.example .env
vim .env        # set MEDIA_PATH + a real COUCHDB_PASSWORD
./setup.sh
```

the setup script makes the config folders, writes the needed files, and starts everything up. if tailscale is already running, it’ll also try to detect the pi’s tailscale ip automatically :)

## a few useful links

- jellyfin → `http://<pi-ip>:8096` or `http://jellyfin.home`
- couchdb → `http://<pi-ip>:5984/_utils` or `http://couchdb.home`
- glances → `http://<pi-ip>:61208` or `http://glances.home`

## notes

### tailscale

for the `.home` names to work, tailscale needs to use the pi as a custom DNS nameserver for the `home` domain. once that’s set in the tailscale admin console, the short names just work from other devices on the tailnet.

### obsidian livesync

the couchdb instance is meant for the self-hosted livesync plugin. use the couchdb url and the creds from `.env`, then set up the plugin on your devices and let it sync.

### other stuff to know

jellyfin is cpu-only so no fancy hardware transcoding on the pi, this is very much a “good enough for me” setup
also nothing here is backed up automatically, so grabbing `config/couchdb/data` and `config/jellyfin/config` every now and then is a decent idea (i just dont care to set that up rn)