# Native NZBGet with Docker Arr apps

This note captures the working lessons from the chat after moving NZBGet out of Docker.

## Native NZBGet settings in Arr apps

Use this in Radarr, Sonarr, Lidarr, Whisparr v2, and Whisparr v3:

```text
Host: 172.18.0.1
Port: 6789
Use SSL: unchecked
Url Base: blank
Username: nzbget
Password: your NZBGet password
Category: radarr / sonarr / lidarr / whisparrv3 / whisparrv2
```

Do not put `/radarr`, `/sonarr`, `/lidarr`, `/whisparr`, or `/nzbget` in the download-client Url Base field unless the Arr app is intentionally connecting through a reverse proxy path.

Do not confuse the two URL/base fields:

```text
Arr app Settings -> General -> URL Base:
Only for browser access through path-based Caddy, for example /radarr.

Arr app Settings -> Download Clients -> NZBGet -> Url Base:
Keep blank for this native NZBGet setup.
```

If you set an Arr app `URL Base`, direct browser access changes too. `http://DEBIAN_SERVER_IP:7878` becomes `http://DEBIAN_SERVER_IP:7878/radarr/`. If you want direct ports like `http://DEBIAN_SERVER_IP:7878/` to keep working, leave every Arr `URL Base` blank and either skip path-based Caddy or use hostname-based Caddy instead.

On this install, `host.docker.internal` resolved but the Arr test still hung. The working fix was to use the Docker Compose network gateway directly:

```text
172.18.0.1
```

Find the gateway and subnet on another install with:

If `docker network inspect media` says `network media not found`, the stack has not created the network yet. Create it by starting the stack from `/opt/media-stack`:

```bash
cd /opt/media-stack
docker compose up -d
```

Do not create the `media` network manually with `docker network create`. Docker Compose needs to create it so the correct Compose labels are attached.

If Docker says the network exists but has an incorrect `com.docker.compose.network` label, it was probably created manually. Remove it and let Compose recreate it:

```bash
docker network rm media
cd /opt/media-stack
docker compose up -d
```

If Docker says the network has active endpoints, stop anything attached first:

```bash
docker ps --filter network=media
cd /opt/media-stack
docker compose down
docker network rm media
docker compose up -d
```

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Gateway}}'
docker network inspect media -f '{{(index .IPAM.Config 0).Subnet}}'
```

## Required Compose setting

Each Arr container needs:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

The `host.docker.internal` name resolves to Docker's bridge gateway, usually a `172.x.x.x` address. That is normal even if the LAN is `192.168.137.0/24`.

## Firewall fix

If Arr tests hang when connecting to native NZBGet, check the Debian firewall. The fix that mattered here was allowing Docker bridge traffic to NZBGet:

```bash
sudo ufw allow in on docker0 to any port 6789 proto tcp
sudo ufw reload
```

For the custom Compose `media` network, also allow the actual Docker subnet. In this setup:

```bash
sudo ufw allow from 172.18.0.0/16 to any port 6789 proto tcp
sudo ufw reload
```

Replace `172.18.0.0/16` with the subnet returned by `docker network inspect media`.

Also confirm NZBGet listens beyond localhost:

```bash
sudo ss -ltnp | grep ':6789'
```

Preferred:

```text
0.0.0.0:6789
```

If it shows only `127.0.0.1:6789`, set `ControlIP` to `0.0.0.0`.

Preferred method: use the NZBGet Web UI:

```text
Settings -> Security -> ControlIP -> 0.0.0.0
Save all changes
```

If editing by hand, find the real active config first. Do not blindly create `/etc/nzbget.conf`; if it opens blank, close it without saving.

```bash
sudo systemctl show nzbget -p ExecStart --value
ps -eo user,group,args | grep '[n]zbget'
sudo find /etc /opt /var/lib /usr/local -iname 'nzbget.conf' -type f 2>/dev/null
```

Then restart:

```bash
sudo systemctl restart nzbget
```

## Remote path mappings

Native NZBGet reports Debian host paths such as:

```text
/mnt/media/adult/downloads/completed/whisparrv3
```

If the Arr container also has `/mnt/media/adult:/mnt/media/adult`, the remote path mapping can be path-identical:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv3
Local Path: /mnt/media/adult/downloads/completed/whisparrv3
```

If the Arr container only has the older `/data/adult` mount, use:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv3
Local Path: /data/adult/downloads/completed/whisparrv3
```

Use the same pattern for Whisparr v2:

```text
Remote Path: /mnt/media/adult/downloads/completed/whisparrv2
Local Path: /mnt/media/adult/downloads/completed/whisparrv2
```

## Whisparr v3 import folder

Whisparr v3's import screen expects a staging folder, commonly:

```text
/data/adult/movies/import
```

or, if using the native path mount:

```text
/mnt/media/adult/movies/import
```

Do not move the whole library into the import folder at once. Test with a small batch first.

## NZBGet fails immediately after a 100% download

If a manual NZB works in another newsreader but NZBGet marks it failed as soon as it finishes, check unpack tools before chasing Whisparr paths. In this setup the cause was missing `unrar`.

Install and verify:

```bash
sudo apt update
sudo apt install -y unrar 7zip p7zip-full ffmpeg
which unrar
which ffmpeg
unrar
ffmpeg -version
sudo systemctl restart nzbget
```

If `unrar` is unavailable on Debian 12 Bookworm, enable `contrib`, `non-free`, and `non-free-firmware`, then run the install again.

On fresh Debian 12 installs, prefer editing:

```text
/etc/apt/sources.list.d/debian.sources
```

If the file is blank, paste this complete Debian 12 Bookworm source definition:

```text
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

Change each Debian `Components:` line from:

```text
Components: main
```

to:

```text
Components: main contrib non-free non-free-firmware
```

If `apt update` complains about duplicate entries, remove or comment the duplicate lines added to `/etc/apt/sources.list`. Keep one source style only: either the Debian 12 `.sources` file or old-style `deb ...` lines, not both.

Recommended final Debian 12 layout:

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo nano /etc/apt/sources.list
```

Comment out every active `deb` line in `/etc/apt/sources.list`, or leave the file empty. Keep the actual Debian repo definition in:

```text
/etc/apt/sources.list.d/debian.sources
```

In NZBGet, confirm:

```text
Settings -> Unpack -> Unpack = yes
```

## ffmpeg is required

Install `ffmpeg` on Debian before trusting imports. The Arr apps and Whisparr use media probing/metadata checks during import, and missing `ffmpeg` can make completed downloads look like path or import failures.

```bash
sudo apt update
sudo apt install -y ffmpeg
which ffmpeg
ffmpeg -version
```
