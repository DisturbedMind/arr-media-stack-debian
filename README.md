![Wolf](assets/wolf.png)

# arr-media-stack-debian

This project documents the working Debian 12.11 media stack for:

- Radarr
- Sonarr
- Lidarr
- Whisparr v3
- Whisparr v2
- Native NZBGet on Debian
- Windows-hosted SMB media shares on `192.168.137.110`

The recommended final setup is: **Arr apps in Docker, NZBGet installed directly on Debian**.

## Quick GitHub Install

Install this project from GitHub on Debian with:

```bash
sudo apt update
sudo apt install -y git
cd /tmp
git clone https://github.com/DisturbedMind/arr-media-stack-debian.git
cd arr-media-stack-debian
chmod +x scripts/install-debian.sh
./scripts/install-debian.sh
```

Use `--start` only after the SMB mounts and NZBGet settings are ready:

```bash
./scripts/install-debian.sh --start
```

Repository: `DisturbedMind/arr-media-stack-debian`.

## 1. Paths Used

Windows shares:

```text
\\192.168.137.110\cinema\movies
\\192.168.137.110\cinema\series
\\192.168.137.110\cinema\music
\\192.168.137.110\adult\movies
\\192.168.137.110\adult\adultseries
```

Debian mount paths:

```text
/mnt/media/cinema
/mnt/media/adult
```

Container paths:

```text
/data/cinema
/data/adult
/mnt/media/cinema
/mnt/media/adult
```

The native NZBGet setup uses `/mnt/media/...` paths. The containers also mount `/mnt/media/...` so remote path mapping is simple.

## 2. Install Docker on Debian 12.11

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl cifs-utils acl nano

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt remove -y "$pkg"
done

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run hello-world
sudo usermod -aG docker "$USER"
```

Log out and back in, then test:

```bash
docker version
docker compose version
```

## 3. Create Folders

```bash
sudo mkdir -p /opt/media-stack/appdata/{radarr,sonarr,lidarr,whisparr-v3,whisparr-v2}
sudo mkdir -p /opt/media-stack/backups
sudo mkdir -p /mnt/media/cinema /mnt/media/adult
sudo chown -R 1000:1000 /opt/media-stack
sudo chmod -R 775 /opt/media-stack
sudo chown root:root /mnt/media/cinema /mnt/media/adult
sudo chmod 0555 /mnt/media/cinema /mnt/media/adult
```

Change `1000:1000` if your Debian user has a different UID/GID:

```bash
id
```

## 4. Mount Windows Shares

Create SMB credentials:

```bash
sudo install -m 0700 -d /etc/samba
sudo nano /etc/samba/media-stack.cred
```

Example:

```ini
username=media-docker
password=REPLACE_WITH_WINDOWS_PASSWORD
domain=WORKGROUP
```

Secure it:

```bash
sudo chmod 600 /etc/samba/media-stack.cred
```

Add the entries from [fstab-smb-example.txt](outputs/fstab-smb-example.txt) to `/etc/fstab`.

Test:

```bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/media/cinema
findmnt /mnt/media/adult
touch /mnt/media/cinema/.docker-write-test
touch /mnt/media/adult/.docker-write-test
rm /mnt/media/cinema/.docker-write-test /mnt/media/adult/.docker-write-test
```

Create download folders:

```bash
mkdir -p /mnt/media/cinema/{movies,series,music,.recyclebin}
mkdir -p /mnt/media/cinema/downloads/{intermediate,completed/{radarr,sonarr,lidarr}}
mkdir -p /mnt/media/adult/{movies,adultseries,.recyclebin}
mkdir -p /mnt/media/adult/downloads/completed/{whisparrv3,whisparrv2}
mkdir -p /mnt/media/adult/movies/import
```

## 5. Install Native NZBGet

Install NZBGet directly on Debian, not in Docker.

```bash
sudo apt update
sudo apt install -y apt-transport-https curl gnupg p7zip-full 7zip ffmpeg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://nzbgetcom.github.io/nzbgetcom.asc -o /etc/apt/keyrings/nzbgetcom.asc
sudo chmod a+r /etc/apt/keyrings/nzbgetcom.asc
echo "deb [arch=all signed-by=/etc/apt/keyrings/nzbgetcom.asc] https://nzbgetcom.github.io/deb stable main" | sudo tee /etc/apt/sources.list.d/nzbgetcom.list
sudo apt update
sudo apt install -y nzbget
sudo systemctl enable --now nzbget
```

Install and verify unpack/media tools. This is not optional: `unrar` is required for many Usenet RAR releases, and `ffmpeg` is required for reliable media probing/import checks. Missing `unrar` made valid NZBs download to 100% and then fail immediately at completion:

```bash
sudo apt update
sudo apt install -y unrar 7zip p7zip-full ffmpeg
which unrar
which ffmpeg
unrar
ffmpeg -version
sudo systemctl restart nzbget
```

If `unrar` is not available on Debian 12 Bookworm, enable `contrib`, `non-free`, and `non-free-firmware` in `/etc/apt/sources.list`:

```text
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
```

Then run:

```bash
sudo apt update
sudo apt install -y unrar 7zip p7zip-full ffmpeg
sudo systemctl restart nzbget
```

In NZBGet, confirm unpacking is enabled:

```text
Settings -> Unpack -> Unpack = yes
```

Make sure NZBGet listens where Docker containers can reach it:

Preferred method: use the NZBGet Web UI, because it writes to the real active config file:

```text
Settings -> Security -> ControlIP -> 0.0.0.0
Save all changes
```

If you prefer editing the file directly, find the real active config first. Do not blindly create `/etc/nzbget.conf`; if that file opens blank, close it without saving.

```bash
sudo systemctl show nzbget -p ExecStart --value
ps -eo user,group,args | grep '[n]zbget'
sudo find /etc /opt /var/lib /usr/local -iname 'nzbget.conf' -type f 2>/dev/null
```

Edit the config file shown by the service/process/find command, then set:

```text
ControlIP=0.0.0.0
```

Restart and verify:

```bash
sudo systemctl restart nzbget
sudo ss -ltnp | grep ':6789'
```

You want to see:

```text
0.0.0.0:6789
```

Open NZBGet:

```text
http://DEBIAN_SERVER_IP:6789
```

Change the default password immediately.

## 6. Fix Firewall for Docker to NZBGet

This was the issue that caused Arr tests to hang.

```bash
sudo ufw allow in on docker0 to any port 6789 proto tcp
sudo ufw reload
```

If the Arr app still hangs when testing NZBGet, use the Docker network gateway directly. In this working setup, Radarr started working when the NZBGet host was set to:

```text
172.18.0.1
```

Find the gateway for the Compose network:

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Gateway}}'
```

Example result:

```text
172.18.0.1
```

Also find the subnet:

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Subnet}}'
```

Example result:

```text
172.18.0.0/16
```

Allow that subnet to reach native NZBGet:

```bash
sudo ufw allow from 172.18.0.0/16 to any port 6789 proto tcp
sudo ufw reload
```

Replace `172.18.0.0/16` with whatever your server returns. The important lesson: `host.docker.internal` may resolve but still hang. The Docker network gateway IP, `172.18.0.1` in this setup, was the reliable fix.

## 7. Configure NZBGet Categories

In NZBGet, set paths:

```text
MainDir:  /mnt/media/cinema/downloads
InterDir: /mnt/media/cinema/downloads/intermediate
DestDir:  /mnt/media/cinema/downloads/completed
```

Categories:

```text
radarr      -> /mnt/media/cinema/downloads/completed/radarr
sonarr      -> /mnt/media/cinema/downloads/completed/sonarr
lidarr      -> /mnt/media/cinema/downloads/completed/lidarr
whisparrv3  -> /mnt/media/adult/downloads/completed/whisparrv3
whisparrv2  -> /mnt/media/adult/downloads/completed/whisparrv2
```

## 8. Start the Arr Stack

This project is meant to be installed from GitHub, not copied by hand from a local Codex folder.

On Debian, install `git` and clone the repository:

```bash
sudo apt update
sudo apt install -y git
cd /tmp
git clone https://github.com/DisturbedMind/arr-media-stack-debian.git
cd arr-media-stack-debian
```

Replace this placeholder with the real GitHub repository URL:

```text
https://github.com/DisturbedMind/arr-media-stack-debian.git
```

Run the installer:

```bash
chmod +x scripts/install-debian.sh
./scripts/install-debian.sh
```

The installer stages these files into `/opt/media-stack`:

```text
compose/native-nzbget.yml       -> /opt/media-stack/compose.yml
examples/media-stack.env.example -> /opt/media-stack/.env
caddy/Caddyfile                 -> /opt/media-stack/caddy/Caddyfile
examples/fstab-smb-example.txt  -> /opt/media-stack/fstab-smb-example.txt
```

The installer also installs/stages the important Debian pieces:

```text
Docker Engine and Compose plugin
native NZBGet
ffmpeg
unrar, when Debian non-free repos are available
cifs-utils for SMB mounts
Caddy container config
```

The installer does not write your SMB password and does not edit `/etc/fstab` automatically. Do those manually:

```bash
sudo nano /etc/samba/media-stack.cred
sudo nano /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/media/cinema
findmnt /mnt/media/adult
```

Use the fstab example staged by the installer:

```bash
cat /opt/media-stack/fstab-smb-example.txt
```

Before starting the stack, confirm NZBGet listens on all interfaces:

Preferred: set it in the NZBGet Web UI:

```text
Settings -> Security -> ControlIP -> 0.0.0.0
Save all changes
```

If editing by hand, locate the active config first. Do not create a blank `/etc/nzbget.conf`.

```bash
sudo systemctl show nzbget -p ExecStart --value
ps -eo user,group,args | grep '[n]zbget'
sudo find /etc /opt /var/lib /usr/local -iname 'nzbget.conf' -type f 2>/dev/null
sudo systemctl restart nzbget
sudo ss -ltnp | grep ':6789'
```

You want:

```text
0.0.0.0:6789
```

Start the stack after SMB mounts and NZBGet are ready:

```bash
cd /opt/media-stack
docker compose config
docker compose pull
docker compose up -d
docker compose ps
```

Or run the installer with `--start` once the manual mount/NZBGet steps are done:

```bash
cd /tmp/arr-media-stack-debian
./scripts/install-debian.sh --start
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
## 9. Internal Caddy Reverse Proxy

Caddy is included as an internal HTTP reverse proxy on port `80`.

This guide runs Caddy in Docker using the official `caddy:2-alpine` image. You do not need to install Caddy with `apt` on Debian for this stack.

The Caddy service is already included in:

```text
compose/native-nzbget.yml
```

The Caddy config is:

```text
caddy/Caddyfile
```

On the Debian server, the live Caddy paths are:

```text
/opt/media-stack/caddy/Caddyfile
/opt/media-stack/caddy/data
/opt/media-stack/caddy/config
```

Before starting Caddy, check whether something else is already using port `80`:

```bash
sudo ss -ltnp | grep ':80'
```

If nothing is returned, port `80` is free. If another service is using it, either stop that service or change the Caddy port mapping in `compose.yml`.

Install the Caddy config into the stack folder:

```bash
cd /opt/media-stack
mkdir -p /opt/media-stack/caddy/data /opt/media-stack/caddy/config
cp caddy/Caddyfile /opt/media-stack/caddy/Caddyfile
```

Start Caddy:

```bash
cd /opt/media-stack
docker compose up -d caddy
docker compose logs --tail=100 caddy
```

Validate that Caddy is listening:

```bash
docker compose ps caddy
curl -I http://127.0.0.1/
```

Use these browser URLs:

```text
Radarr:      http://DEBIAN_SERVER_IP/radarr/
Sonarr:      http://DEBIAN_SERVER_IP/sonarr/
Lidarr:      http://DEBIAN_SERVER_IP/lidarr/
Whisparr v3: http://DEBIAN_SERVER_IP/whisparrv3/
Whisparr v2: http://DEBIAN_SERVER_IP/whisparrv2/
NZBGet:      http://DEBIAN_SERVER_IP/nzbget/
```

Test the routes from Debian:

```bash
curl -I http://127.0.0.1/radarr/
curl -I http://127.0.0.1/sonarr/
curl -I http://127.0.0.1/lidarr/
curl -I http://127.0.0.1/whisparrv3/
curl -I http://127.0.0.1/whisparrv2/
curl -I http://127.0.0.1/nzbget/
```

Open port `80` only to the internal LAN:

```bash
sudo ufw allow from 192.168.137.0/24 to any port 80 proto tcp
sudo ufw reload
```

The Caddy config lives at:

```text
/opt/media-stack/caddy/Caddyfile
```

Project copy:

```text
caddy/Caddyfile
```

Set URL Base inside each Arr app:

```text
Radarr:      Settings -> General -> URL Base: /radarr
Sonarr:      Settings -> General -> URL Base: /sonarr
Lidarr:      Settings -> General -> URL Base: /lidarr
Whisparr v3: Settings -> General -> URL Base: /whisparrv3
Whisparr v2: Settings -> General -> URL Base: /whisparrv2
```

Then restart the containers:

```bash
cd /opt/media-stack
docker compose restart radarr sonarr lidarr whisparrv3 whisparrv2 caddy
```

Important: these Arr URL Base settings are only for browser access through Caddy. They are not download-client settings.

NZBGet is native on Debian and does not need to know about Caddy for the Arr apps to work. Caddy proxies `/nzbget/` to:

```text
172.18.0.1:6789
```

If your Docker network gateway is different, update the `reverse_proxy` line in `/opt/media-stack/caddy/Caddyfile` using:

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Gateway}}'
```

Then reload Caddy:

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

If the NZBGet web UI behaves strangely through `/nzbget/`, use the direct internal URL for NZBGet instead:

```text
http://DEBIAN_SERVER_IP:6789
```

Do not let a reverse proxy problem block downloads. The Arr apps should still connect to NZBGet directly on `172.18.0.1:6789`.

Useful Caddy commands:

```bash
cd /opt/media-stack
docker compose logs -f caddy
docker compose restart caddy
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## 10. Configure Arr Download Clients

In every Arr app:

```text
Host: 172.18.0.1
Port: 6789
Use SSL: unchecked
Url Base: blank
Username: nzbget
Password: your NZBGet password
Category: app-specific category
```

Categories:

```text
Radarr:      radarr
Sonarr:      sonarr
Lidarr:      lidarr
Whisparr v3: whisparrv3
Whisparr v2: whisparrv2
```

Do not use `/radarr`, `/sonarr`, `/lidarr`, `/whisparr`, or `/nzbget` in the download client Url Base field.

Even when Caddy is enabled, keep the download-client Url Base blank. Caddy is for your browser, not for Arr-to-NZBGet traffic.

If your Docker network gateway is not `172.18.0.1`, use the gateway returned by:

```bash
docker network inspect media -f '{{(index .IPAM.Config 0).Gateway}}'
```

If `host.docker.internal` works on your server, it is also fine. On this install it made the Arr test hang, and `172.18.0.1` fixed it.

## 11. Configure Root Folders

Recommended root folders:

```text
Radarr:      /mnt/media/cinema/movies
Sonarr:      /mnt/media/cinema/series
Lidarr:      /mnt/media/cinema/music
Whisparr v3: /mnt/media/adult/movies
Whisparr v2: /mnt/media/adult/adultseries
```

Recycle bins:

```text
Radarr/Sonarr/Lidarr:      /mnt/media/cinema/.recyclebin
Whisparr v3/Whisparr v2:   /mnt/media/adult/.recyclebin
```

## 12. Remote Path Mappings

Because native NZBGet reports `/mnt/media/...`, use matching paths.

The `Host` field must exactly match the host used in the NZBGet download client. These examples use the working gateway IP:

```text
172.18.0.1
```

Whisparr v3:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv3
Local Path:  /mnt/media/adult/downloads/completed/whisparrv3
```

Whisparr v2:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/adult/downloads/completed/whisparrv2
Local Path:  /mnt/media/adult/downloads/completed/whisparrv2
```

Radarr:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/radarr
Local Path:  /mnt/media/cinema/downloads/completed/radarr
```

Sonarr:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/sonarr
Local Path:  /mnt/media/cinema/downloads/completed/sonarr
```

Lidarr:

```text
Host: 172.18.0.1
Remote Path: /mnt/media/cinema/downloads/completed/lidarr
Local Path:  /mnt/media/cinema/downloads/completed/lidarr
```

## 13. Whisparr v3 Import Folder

Whisparr v3 is awkward compared with Radarr. Use a small staging folder first:

```text
/mnt/media/adult/movies/import
```

From Windows:

```text
\\192.168.137.110\adult\movies\import
```

Test with a few movies before moving a large library.

## 14. Validation Commands

Run on Debian:

```bash
findmnt /mnt/media/cinema
findmnt /mnt/media/adult
docker compose -f /opt/media-stack/compose.yml ps
```

Check paths inside containers:

```bash
docker exec radarr ls -la /mnt/media/cinema/movies
docker exec sonarr ls -la /mnt/media/cinema/series
docker exec lidarr ls -la /mnt/media/cinema/music
docker exec whisparrv3 ls -la /mnt/media/adult/movies
docker exec whisparrv2 ls -la /mnt/media/adult/adultseries
docker exec whisparrv3 ls -la /mnt/media/adult/downloads/completed/whisparrv3
```

Check NZBGet from inside a container:

```bash
docker exec lidarr sh -lc 'wget -T 5 -S -O- http://172.18.0.1:6789/jsonrpc 2>&1 | head -80'
```

Good signs include:

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

If an NZB downloads to 100% and then fails instantly, check `unrar` first. Also verify `ffmpeg`, because imports and media checks can fail or behave strangely without it:

```bash
which unrar
sudo apt install -y unrar 7zip p7zip-full ffmpeg
sudo systemctl restart nzbget
```

That symptom can look like a path problem, but in this setup it was NZBGet failing during unpack because `unrar` was missing.

## 15. Backups and Safety

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

Back up app config:

```bash
cd /opt/media-stack
docker compose stop
sudo tar -czf /opt/media-stack/backups/appdata-$(date +%F-%H%M).tgz appdata .env compose.yml
docker compose up -d
```

## 16. Project Files

- [Debian installer](scripts/install-debian.sh)
- [Native NZBGet Compose](compose/native-nzbget.yml)
- [Docker NZBGet Compose](compose/docker-nzbget.yml)
- [Caddyfile](caddy/Caddyfile)
- [Env example](examples/media-stack.env.example)
- [SMB fstab example](examples/fstab-smb-example.txt)
- [Native NZBGet notes](outputs/native-nzbget-arr-troubleshooting.md)
- [ZIP bundle](outputs/debian-hotio-media-stack-pack.zip)







