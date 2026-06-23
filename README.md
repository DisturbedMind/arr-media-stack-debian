<p align="center">
  <img alt="Debian" src="https://img.shields.io/badge/Debian-12-A81D33?logo=debian&logoColor=white">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
  <img alt="Arr Stack" src="https://img.shields.io/badge/Arr-Radarr%20%7C%20Sonarr%20%7C%20Lidarr-ffc230">
  <img alt="NZBGet" src="https://img.shields.io/badge/NZBGet-native-2EA043">
  <img alt="Storage" src="https://img.shields.io/badge/Storage-SMB-6f42c1">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Debian-A81D33?logo=debian&logoColor=white">
</p>

![Wolf](assets/wolf.png)

# Debian ARR Media Stack Installer

A Debian 12.11 install guide and helper script for a home ARR media stack using Docker for Radarr, Sonarr, Lidarr, Whisparr v3, and Whisparr v2, with NZBGet installed natively on Debian and media stored on Windows SMB shares.

This project is built around one practical goal: keep the application configs safe in `/opt/media-stack`, keep the media on the Windows storage box, and make every container see the same paths so imports do not turn into a path-mapping circus.

## Script Description

`scripts/install-debian.sh` prepares a Debian 12 server for the stack. It installs base packages, Docker Engine, native NZBGet, `unrar`, `ffmpeg`, and the Docker Compose plugin, then stages the Compose file, example environment file, Caddy examples, and SMB fstab example under `/opt/media-stack`.

The script intentionally does not write your SMB password, does not edit `/etc/fstab`, and does not start the stack unless you pass `--start`. Those steps are left manual so the storage mounts can be verified before any app starts writing to them.

## Target Setup

Apps:

```text
Radarr        Docker, hotio image
Sonarr        Docker, hotio image
Lidarr        Docker, hotio image
Whisparr v3   Docker, hotio image
Whisparr v2   Docker, hotio image
NZBGet        Native Debian package
Caddy         Optional reverse proxy
```

Storage:

```text
Windows storage server: 192.168.137.110
Cinema movies:          \\192.168.137.110\cinema\movies
Cinema series:          \\192.168.137.110\cinema\series
Cinema music:           \\192.168.137.110\cinema\music
Adult movies:           \\192.168.137.110\adult\movies
Adult series:           \\192.168.137.110\adult\adultseries
```

Debian mount paths:

```text
/mnt/media/cinema
/mnt/media/adult
```

Container paths:

```text
/mnt/media/cinema
/mnt/media/adult
/data/cinema
/data/adult
```

The `/mnt/media/...` paths are the important ones. Native NZBGet reports those paths, and the containers can see those same paths, so remote path mappings stay simple.

## Bring Your Own Usenet Accounts

This project installs the stack, but it does not include Usenet access or indexer accounts. Before the Arr apps can search and download, you need:

```text
1. One or more Usenet indexers added in each Arr app.
2. A Usenet provider/news server added in NZBGet.
```

Use only content you have the right to access. Indexer registrations, API limits, invite status, pricing, and provider deals change often, so treat the lists below as starting points to research.

Common NZB indexers to look at:

- <a href="https://nzbgeek.info/" target="_blank" rel="noopener noreferrer">NZBGeek</a>
- <a href="https://nzbfinder.ws/" target="_blank" rel="noopener noreferrer">NZBFinder</a>
- <a href="https://nzbplanet.net/" target="_blank" rel="noopener noreferrer">NZBPlanet</a>
- <a href="https://drunkenslug.com/" target="_blank" rel="noopener noreferrer">DrunkenSlug</a>
- <a href="https://dognzb.cr/" target="_blank" rel="noopener noreferrer">DogNZB</a>

Common Usenet providers/news servers to look at:

- <a href="https://www.newshosting.com/" target="_blank" rel="noopener noreferrer">Newshosting</a>
- <a href="https://www.eweka.nl/en" target="_blank" rel="noopener noreferrer">Eweka</a>
- <a href="https://www.easynews.com/" target="_blank" rel="noopener noreferrer">Easynews</a>
- <a href="https://www.usenetserver.com/" target="_blank" rel="noopener noreferrer">UsenetServer</a>
- <a href="https://www.tweaknews.eu/en" target="_blank" rel="noopener noreferrer">TweakNews</a>

In the Arr apps, indexers usually go under:

```text
Settings -> Indexers
```

In NZBGet, your news server goes under:

```text
Settings -> News-Servers
```

## Install Steps

### 1. Download The Project

Run this on the Debian 12.11 server:

```bash
sudo apt update
sudo apt install -y git
cd /tmp
git clone https://github.com/DisturbedMind/arr-media-stack-debian.git
cd arr-media-stack-debian
```

If you already cloned it:

```bash
cd /tmp/arr-media-stack-debian
git pull
```

### 2. Run The Installer

Stage the stack without starting the containers:

```bash
chmod +x scripts/install-debian.sh
./scripts/install-debian.sh
```

Use `--start` only after SMB mounts and NZBGet settings are ready:

```bash
./scripts/install-debian.sh --start
```

After the installer, log out and back in if it added your user to the `docker` group.

### 3. Check Debian Non-Free Repos

`unrar` is a must for many Usenet downloads. `ffmpeg` is also a must for reliable media probing and imports.

On Debian 12, make sure `/etc/apt/sources.list.d/debian.sources` includes:

```text
Components: main contrib non-free non-free-firmware
```

If `/etc/apt/sources.list.d/debian.sources` is blank, use this complete Bookworm source file:

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

If `apt update` complains about duplicate Debian entries, comment out every active `deb` line in `/etc/apt/sources.list` and keep the real Debian repo definition in `/etc/apt/sources.list.d/debian.sources`.

Then run:

```bash
sudo apt update
sudo apt install -y unrar 7zip p7zip-full ffmpeg
which unrar
ffmpeg -version
sudo systemctl restart nzbget
```

### 4. Create SMB Credentials

Create a credentials file for the Windows storage shares:

```bash
sudo nano /etc/samba/media-stack.cred
```

Use:

```text
username=YOUR_WINDOWS_USER
password=YOUR_WINDOWS_PASSWORD
domain=WORKGROUP
```

Secure it:

```bash
sudo chmod 600 /etc/samba/media-stack.cred
```

### 5. Mount The Windows Shares

Create the mount points if they do not already exist:

```bash
sudo mkdir -p /mnt/media/cinema /mnt/media/adult
```

Check your Debian user id and group id:

```bash
id
```

Most single-user Debian installs use `uid=1000,gid=1000`. If your `id` command shows different values, change `uid=1000,gid=1000` in the example below.

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Paste this at the bottom of `/etc/fstab`:

```text
//192.168.137.110/cinema /mnt/media/cinema cifs credentials=/etc/samba/media-stack.cred,uid=1000,gid=1000,iocharset=utf8,vers=3.0,file_mode=0775,dir_mode=0775,noperm,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60 0 0
//192.168.137.110/adult  /mnt/media/adult  cifs credentials=/etc/samba/media-stack.cred,uid=1000,gid=1000,iocharset=utf8,vers=3.0,file_mode=0775,dir_mode=0775,noperm,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60 0 0
```

Save the file, then mount and verify:

```bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/media/cinema
findmnt /mnt/media/adult
```

You should see:

```text
//192.168.137.110/cinema  /mnt/media/cinema
//192.168.137.110/adult   /mnt/media/adult
```

Confirm you can list the mounted shares:

```bash
ls -la /mnt/media/cinema
ls -la /mnt/media/adult
```

### 6. Create Media And Download Folders

```bash
mkdir -p /mnt/media/cinema/{movies,series,music,.recyclebin}
mkdir -p /mnt/media/cinema/downloads/{intermediate,completed/{radarr,sonarr,lidarr}}
mkdir -p /mnt/media/adult/{movies,adultseries,.recyclebin}
mkdir -p /mnt/media/adult/downloads/completed/{whisparrv3,whisparrv2}
mkdir -p /mnt/media/adult/movies/import
```

### 7. Configure Native NZBGet

Open NZBGet:

```text
http://DEBIAN_SERVER_IP:6789
```

Change the default password immediately.

Set:

```text
Settings -> Security -> ControlIP -> 0.0.0.0
Settings -> Unpack -> Unpack -> yes
```

Set paths:

```text
MainDir:  /mnt/media/cinema/downloads
InterDir: /mnt/media/cinema/downloads/intermediate
DestDir:  /mnt/media/cinema/downloads/completed
```

Set categories:

```text
radarr      -> /mnt/media/cinema/downloads/completed/radarr
sonarr      -> /mnt/media/cinema/downloads/completed/sonarr
lidarr      -> /mnt/media/cinema/downloads/completed/lidarr
whisparrv3  -> /mnt/media/adult/downloads/completed/whisparrv3
whisparrv2  -> /mnt/media/adult/downloads/completed/whisparrv2
```

Restart and verify the listener:

```bash
sudo systemctl restart nzbget
sudo ss -ltnp | grep ':6789'
```

You want NZBGet listening on:

```text
0.0.0.0:6789
```

### 8. Start The Docker Stack

```bash
cd /opt/media-stack
docker compose up -d
docker compose ps
```

Direct app URLs:

```text
Radarr:      http://DEBIAN_SERVER_IP:7878
Sonarr:      http://DEBIAN_SERVER_IP:8989
Lidarr:      http://DEBIAN_SERVER_IP:8686
Whisparr v3: http://DEBIAN_SERVER_IP:6969
Whisparr v2: http://DEBIAN_SERVER_IP:6970
NZBGet:      http://DEBIAN_SERVER_IP:6789
```

### 9. Allow Docker To Reach Native NZBGet

The working fix for this install was to use the Docker Compose network gateway:

```text
172.18.0.1
```

Allow the Compose subnet to reach NZBGet:

```bash
sudo ufw allow from 172.18.0.0/16 to any port 6789 proto tcp
sudo ufw reload
```

Confirm the gateway:

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Gateway}}'
```

Expected:

```text
172.18.0.1
```

### 10. Configure Arr Download Clients

In every Arr app, add NZBGet:

```text
Host: 172.18.0.1
Port: 6789
Use SSL: unchecked
Url Base: blank
Username: nzbget
Password: your NZBGet password
```

Use these categories:

```text
Radarr:      radarr
Sonarr:      sonarr
Lidarr:      lidarr
Whisparr v3: whisparrv3
Whisparr v2: whisparrv2
```

Do not put `/radarr`, `/sonarr`, `/lidarr`, `/whisparr`, or `/nzbget` in the download client `Url Base` field. Caddy is for browser access; Arr-to-NZBGet traffic should go directly to `172.18.0.1:6789`.

### 11. Configure Root Folders

Use:

```text
Radarr:      /mnt/media/cinema/movies
Sonarr:      /mnt/media/cinema/series
Lidarr:      /mnt/media/cinema/music
Whisparr v3: /mnt/media/adult/movies
Whisparr v2: /mnt/media/adult/adultseries
```

Recycle bins:

```text
Radarr/Sonarr/Lidarr:    /mnt/media/cinema/.recyclebin
Whisparr v3/Whisparr v2: /mnt/media/adult/.recyclebin
```

### 12. Configure Remote Path Mappings

Because native NZBGet reports `/mnt/media/...`, the remote and local paths should match.

The `Host` field must exactly match the NZBGet download client host:

```text
172.18.0.1
```

Mappings:

```text
Radarr
Host:        172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/radarr
Local Path:  /mnt/media/cinema/downloads/completed/radarr

Sonarr
Host:        172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/sonarr
Local Path:  /mnt/media/cinema/downloads/completed/sonarr

Lidarr
Host:        172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/lidarr
Local Path:  /mnt/media/cinema/downloads/completed/lidarr

Whisparr v3
Host:        172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv3
Local Path:  /mnt/media/adult/downloads/completed/whisparrv3

Whisparr v2
Host:        172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv2
Local Path:  /mnt/media/adult/downloads/completed/whisparrv2
```

### 13. Whisparr v3 Import Folder

Whisparr v3 does not import existing movies as smoothly as Radarr. Use a small staging folder first:

```text
/mnt/media/adult/movies/import
```

From Windows:

```text
\\192.168.137.110\adult\movies\import
```

Test with a few movies before pointing Whisparr v3 at a large library.

### 14. Choose Caddy Access

Caddy is optional. Direct ports work without it.

Use one of these layouts:

```text
Direct ports:
Use http://DEBIAN_SERVER_IP:7878 and friends.
Keep every Arr URL Base blank.

Internal Docker Caddy, path-based:
Use http://DEBIAN_SERVER_IP/radarr/
Requires Arr URL Base values like /radarr.

Internal Docker Caddy, hostname-based wolf.den:
Use http://radarr.wolf.den/
Keep every Arr URL Base blank.

External/native Caddy, hostname-based wolf.den:
Use http://radarr.wolf.den/
Keep every Arr URL Base blank.
```

For the current `wolf.den` setup with Docker Caddy inside this stack:

```bash
cd /opt/media-stack
mkdir -p /opt/media-stack/caddy/data /opt/media-stack/caddy/config
cp /tmp/arr-media-stack-debian/caddy/Caddyfile.internal-wolf.den.example /opt/media-stack/caddy/Caddyfile
docker compose --profile internal-caddy up -d caddy
docker compose ps caddy
docker compose logs --tail=100 caddy
```

Point DNS records to the Debian server IP that publishes Docker port `80`:

```text
radarr.wolf.den
sonarr.wolf.den
lidarr.wolf.den
whisparrv3.wolf.den
whisparrv2.wolf.den
nzbget.wolf.den
```

For an already-running external/native Caddy, use:

```text
caddy/Caddyfile.external-wolf.den.example
```

Replace `ARR_STACK_IP` with the Debian ARR stack IP. If external Caddy is on the same Debian server as the stack, use `127.0.0.1`. Do not use `172.18.0.1` in an external Caddyfile.

Open port `80` to the LAN:

```bash
sudo ufw allow from 192.168.137.0/24 to any port 80 proto tcp
sudo ufw reload
```

### 15. Validate The Install

Run on Debian:

```bash
findmnt /mnt/media/cinema
findmnt /mnt/media/adult
cd /opt/media-stack
docker compose ps
docker exec radarr ls -la /mnt/media/cinema/movies
docker exec sonarr ls -la /mnt/media/cinema/series
docker exec lidarr ls -la /mnt/media/cinema/music
docker exec whisparrv3 ls -la /mnt/media/adult/movies
docker exec whisparrv2 ls -la /mnt/media/adult/adultseries
docker exec lidarr sh -lc 'wget -T 5 -S -O- http://172.18.0.1:6789/jsonrpc 2>&1 | head -80'
```

Good NZBGet connectivity signs:

```text
401 Unauthorized
400 Bad Request
JSON response
```

Bad signs:

```text
Connection timed out
Connection refused
Could not resolve host
```

### 16. Back Up App Config

App configs live under:

```text
/opt/media-stack/appdata
```

Back them up:

```bash
cd /opt/media-stack
docker compose stop
sudo tar -czf /opt/media-stack/backups/appdata-$(date +%F-%H%M).tgz appdata .env compose.yml
docker compose up -d
```

Safe container recreation:

```bash
cd /opt/media-stack
docker compose up -d --force-recreate radarr
```

Avoid:

```bash
docker compose down -v
docker system prune --volumes
rm -rf /mnt/media/cinema/*
rm -rf /mnt/media/adult/*
```

## Troubleshooting

### Docker Permission Denied

If Docker says permission denied for `/var/run/docker.sock`, either run the command with `sudo` or log out and back in after being added to the `docker` group:

```bash
sudo usermod -aG docker "$USER"
```

Then log out and back in.

### NZBGet Test Hangs In Arr Apps

Use:

```text
Host: 172.18.0.1
Port: 6789
Url Base: blank
```

Also confirm the firewall rule:

```bash
sudo ufw allow from 172.18.0.0/16 to any port 6789 proto tcp
sudo ufw reload
```

`host.docker.internal` may resolve to a `172.x.x.x` address and still hang. On this install, `172.18.0.1` was the reliable fix.

### NZB Downloads To 100 Percent Then Fails

Check `unrar` first:

```bash
which unrar
unrar
sudo apt install -y unrar 7zip p7zip-full ffmpeg
sudo systemctl restart nzbget
```

Missing `unrar` can make a good NZB fail immediately after download because NZBGet cannot unpack it. Missing `ffmpeg` can break media probing/import behavior later.

### Blank `/etc/nzbget.conf`

Do not create a new blank config. Find the active config first:

```bash
sudo systemctl show nzbget -p ExecStart --value
ps -eo user,group,args | grep '[n]zbget'
sudo find /etc /opt /var/lib /usr/local -iname 'nzbget.conf' -type f 2>/dev/null
```

The preferred method is still the NZBGet Web UI:

```text
Settings -> Security -> ControlIP -> 0.0.0.0
```

### Debian Apt Duplicate Source Warnings

Use one Debian source style only. For this guide, keep the real Debian repo configuration in:

```text
/etc/apt/sources.list.d/debian.sources
```

Comment out duplicate active `deb` lines in:

```text
/etc/apt/sources.list
```

Then:

```bash
sudo apt update
```

### Docker Network `media` Not Found

Start the stack once so Compose creates the network:

```bash
cd /opt/media-stack
docker compose up -d
```

Do not create the `media` network manually.

### Docker Network Has Incorrect Compose Label

If Docker says:

```text
network media was found but has incorrect label com.docker.compose.network set to "" (expected: "media")
```

remove the manually-created network and let Compose recreate it:

```bash
cd /opt/media-stack
docker compose down
docker network rm media
docker compose up -d
```

### Caddy Service Not Found

If this fails:

```bash
sudo systemctl restart caddy
```

with:

```text
Unit caddy.service could not be found.
```

then Caddy is not installed as a native Debian service on that machine. That is fine if you chose Docker Caddy.

Check for a Caddy container:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i caddy
```

If there is no Caddy container and no native Caddy service, start the internal Docker Caddy profile:

```bash
cd /opt/media-stack
cp /tmp/arr-media-stack-debian/caddy/Caddyfile.internal-wolf.den.example /opt/media-stack/caddy/Caddyfile
docker compose --profile internal-caddy up -d caddy
docker compose ps caddy
```

### Caddy Port 80 Already In Use

Check:

```bash
sudo ss -ltnp | grep ':80'
```

If `docker-proxy` owns port `80`, a Caddy container is already running. If native Caddy owns it, do not also start Docker Caddy on port `80`.

### Caddy Cannot Assign Requested Address

This means the Caddyfile has a `bind` line for an IP the server does not own.

Check:

```bash
ip -br addr
```

For this guide, the safest fix is usually to remove `bind 192.168.137.x` lines and let Caddy listen normally.

### Hostname Works By IP But Not By Name

Check DNS:

```bash
nslookup radarr.wolf.den
```

Bypass DNS from Windows:

```powershell
curl.exe -v --resolve radarr.wolf.den:80:DEBIAN_SERVER_IP http://radarr.wolf.den/
```

If `--resolve` works but the browser does not, the client is using stale or wrong DNS.

### Browser Uses HTTPS By Mistake

This stack is internal HTTP unless you deliberately add TLS:

```text
http://radarr.wolf.den/
```

Do not use:

```text
https://radarr.wolf.den/
```

### Whisparr v3 Does Not Import Existing Movies

Use the staging folder:

```text
/mnt/media/adult/movies/import
```

Then in Whisparr v3, process the import folder from the UI. Start with a few files before trying a full library.

## Project Files

- [Debian installer](scripts/install-debian.sh)
- [Native NZBGet Compose](compose/native-nzbget.yml)
- [Docker NZBGet Compose](compose/docker-nzbget.yml)
- [Path-based Docker Caddyfile](caddy/Caddyfile)
- [Hostname Docker Caddy example](caddy/Caddyfile.hostnames.example)
- [Internal wolf.den Docker Caddy example](caddy/Caddyfile.internal-wolf.den.example)
- [Wolf Den external Caddy example](caddy/Caddyfile.external-wolf.den.example)
- [External Caddy on 192.168.137.251 example](caddy/Caddyfile.external-192.168.137.251.example)
- [External Caddy port-mirror example](caddy/Caddyfile.external-port-mirror-192.168.137.251.example)
- [Env example](examples/media-stack.env.example)
- [SMB fstab example](examples/fstab-smb-example.txt)
- [Troubleshooting notes](outputs/native-nzbget-arr-troubleshooting.md)
- [ZIP bundle](outputs/debian-hotio-media-stack-pack.zip)
