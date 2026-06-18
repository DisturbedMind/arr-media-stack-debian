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

If `unrar` is not available on Debian 12 Bookworm, enable `contrib`, `non-free`, and `non-free-firmware`.

On fresh Debian 12 installs, do not blindly add duplicate `deb ...` lines to `/etc/apt/sources.list`. Debian often uses this file instead:

```text
/etc/apt/sources.list.d/debian.sources
```

Edit it:

```bash
sudo nano /etc/apt/sources.list.d/debian.sources
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

Then run:

```bash
sudo apt update
sudo apt install -y unrar 7zip p7zip-full ffmpeg
sudo systemctl restart nzbget
```

If `apt update` complains about duplicate entries, remove or comment the duplicate lines you added to `/etc/apt/sources.list`. Keep one source style only: either the Debian 12 `.sources` file or old-style `deb ...` lines, not both.

Recommended final Debian 12 layout:

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo nano /etc/apt/sources.list
```

Comment out every active `deb` line in `/etc/apt/sources.list`, or leave the file empty. Then save the real Debian repo configuration in:

```text
/etc/apt/sources.list.d/debian.sources
```

After that, `apt update` should no longer warn that targets are configured multiple times.

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

If this says `network media not found`, the stack has not created the network yet. Create it by starting the stack:

```bash
cd /opt/media-stack
docker compose up -d
```

Do not create the `media` network manually with `docker network create`. Docker Compose needs to create it so the correct Compose labels are attached.

If you already created it manually, Compose may fail with:

```text
network media was found but has incorrect label com.docker.compose.network set to "" (expected: "media")
```

Fix that by removing the manually-created network, then let Compose recreate it:

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

This project pins the Compose `media` network to:

```text
Subnet:  172.18.0.0/16
Gateway: 172.18.0.1
```

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

The included Docker Caddy service is opt-in. Normal `docker compose up -d` starts the Arr containers only and does not bind port `80`.

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

These direct URLs assume the Arr app `URL Base` fields are blank. If you later set `URL Base` for path-based Caddy access, the direct URLs also need the path, for example `http://DEBIAN_SERVER_IP:7878/radarr/`.
## 9. Internal Caddy Reverse Proxy

Caddy is included as an internal HTTP reverse proxy on port `80`.

This guide runs Caddy in Docker using the official `caddy:2-alpine` image. You do not need to install Caddy with `apt` on Debian for this stack.

You have three clean choices:

```text
Option A: Path-based Caddy
Use http://DEBIAN_SERVER_IP/radarr/
Requires Arr URL Base values like /radarr.
Plain direct-port URLs change to http://DEBIAN_SERVER_IP:7878/radarr/.

Option B: Direct ports, or hostname-based Caddy
Use http://DEBIAN_SERVER_IP:7878/ directly, or names like http://radarr.media.home.arpa/.
Keep every Arr URL Base blank.
This is usually less confusing while you are still testing downloads and imports.

Option C: External LAN Caddy on 192.168.137.253
Use names like http://radarr.wolf.den/ through your existing Caddy server.
Keep every Arr URL Base blank.
This is the recommended option if you already run Caddy at 192.168.137.253.
```

On this install, the Caddy server moved to `192.168.137.253` and the DNS zone is `wolf.den`. Use this current file:

```text
caddy/Caddyfile.external-wolf.den.example
```

It expects these DNS records:

```text
radarr.wolf.den       -> 192.168.137.253
sonarr.wolf.den       -> 192.168.137.253
lidarr.wolf.den       -> 192.168.137.253
whisparrv3.wolf.den   -> 192.168.137.253
whisparrv2.wolf.den   -> 192.168.137.253
nzbget.wolf.den       -> 192.168.137.253
```

If only `radarr.wolf.den` works, check all three layers:

```bash
# 1. DNS should return 192.168.137.253 for every name.
for app in radarr sonarr lidarr whisparrv3 whisparrv2 nzbget; do getent hosts "$app.wolf.den"; done

# 2. Caddyfile should contain every wolf.den hostname.
grep -E 'radarr|sonarr|lidarr|whisparrv3|whisparrv2|nzbget' /etc/caddy/Caddyfile

# 3. From the Caddy server, the backends should answer on their ports.
curl -I http://ARR_STACK_IP:7878
curl -I http://ARR_STACK_IP:8989
curl -I http://ARR_STACK_IP:8686
curl -I http://ARR_STACK_IP:6969
curl -I http://ARR_STACK_IP:6970
curl -I http://ARR_STACK_IP:6789
```

Replace `ARR_STACK_IP` with the Debian ARR stack IP, or use `127.0.0.1` if Caddy and the ARR stack are on the same machine.

If the browser says `connection refused` for `http://radarr.wolf.den`, troubleshoot Caddy itself first. That error usually means nothing is listening on `192.168.137.253:80`, or the Caddy server firewall is rejecting port `80`.

Run this on the Caddy server:

```bash
getent hosts radarr.wolf.den
sudo systemctl status caddy --no-pager
sudo ss -ltnp | grep ':80'
sudo journalctl -u caddy -n 80 --no-pager
sudo ufw status verbose
```

Good signs:

```text
radarr.wolf.den resolves to 192.168.137.253
caddy.service is active/running
ss shows caddy listening on 0.0.0.0:80 or [::]:80
```

If Caddy is not running:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
sudo journalctl -u caddy -n 80 --no-pager
```

If Caddy is running but port `80` is blocked by UFW:

```bash
sudo ufw allow from 192.168.137.0/24 to any port 80 proto tcp
sudo ufw reload
```

From another machine on the LAN, test:

```bash
curl -I http://radarr.wolf.den
```

If Caddy is running and `http://192.168.137.253` responds, but `http://radarr.wolf.den` does not, split DNS from Caddy with a Host-header test.

Run this on the Caddy server:

```bash
curl -I -H 'Host: radarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: sonarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: lidarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: whisparrv3.wolf.den' http://127.0.0.1
curl -I -H 'Host: whisparrv2.wolf.den' http://127.0.0.1
curl -I -H 'Host: nzbget.wolf.den' http://127.0.0.1
```

If those work from the Caddy server, Caddy is matching the hostnames correctly and the problem is on the client/DNS side. On a Windows client, check:

```powershell
nslookup radarr.wolf.den
nslookup sonarr.wolf.den
Resolve-DnsName radarr.wolf.den
curl.exe -v --resolve radarr.wolf.den:80:192.168.137.253 http://radarr.wolf.den/
ipconfig /flushdns
```

The `--resolve` test bypasses DNS. If it works but normal browsing does not, your client is not using the DNS records you created, or it has a stale DNS cache.

If the `--resolve` test still says `Connection refused`, DNS is not the problem. Your client is reaching `192.168.137.253`, but port `80` is not accepting the connection from the LAN.

Run these on the Caddy server:

```bash
ip -br addr
sudo systemctl status caddy --no-pager
sudo ss -ltnp '( sport = :80 )'
sudo ss -4ltnp '( sport = :80 )'
sudo ss -6ltnp '( sport = :80 )'
sudo grep -nE 'bind|wolf.den|reverse_proxy|:80' /etc/caddy/Caddyfile
curl -v -H 'Host: radarr.wolf.den' http://127.0.0.1/
curl -v -H 'Host: radarr.wolf.den' http://192.168.137.253/
```

Read the result like this:

```text
127.0.0.1 works, 192.168.137.253 fails:
Caddy is bound only to localhost or the server does not actually own 192.168.137.253.

Both 127.0.0.1 and 192.168.137.253 work on the Caddy server, but Windows still refuses:
The block is between Windows and the Caddy server. Check the Caddy server firewall, host firewall, VM/NAT rules, or the Windows network path.

Neither works:
Caddy is running as a service but is not listening correctly on port 80, or the Caddyfile did not load.
```

If `ss` shows Caddy listening only on `127.0.0.1:80`, remove any localhost-only bind:

```bash
sudo sed -i '/^[[:space:]]*bind /d' /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

Then confirm Caddy is listening on the LAN:

```bash
sudo ss -ltnp '( sport = :80 )'
curl -v -H 'Host: radarr.wolf.den' http://192.168.137.253/
```

If `ip -br addr` does not show `192.168.137.253` on a network interface, fix the server IP first or change DNS to the IP the Caddy server actually owns.

`docker0` being `DOWN` does not explain this specific symptom. A localhost `200` with a LAN-IP failure happens at the Caddy listener/network layer before Docker is involved. Docker matters later, when Caddy proxies to the Arr backend ports.

If `ss` shows Caddy listening on `*:80`, check IPv4 specifically:

```bash
sudo ss -4ltnp '( sport = :80 )'
sudo ss -6ltnp '( sport = :80 )'
```

If `ss -6` shows Caddy but `ss -4` shows nothing, Caddy is only listening on IPv6. Force an IPv4 listener by using an explicit `:80` site address in `/etc/caddy/Caddyfile` and removing any `bind` lines:

```bash
sudo sed -i '/^[[:space:]]*bind /d' /etc/caddy/Caddyfile
sudo sed -i 's/^http:\/\/radarr\.wolf\.den/:80/' /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
sudo ss -4ltnp '( sport = :80 )'
```

Only do that quick test temporarily, because it makes one catch-all site. If it fixes IPv4 access, rebuild the Caddyfile using a single `:80` site with host matchers.

If `ss -4` shows Caddy on `*:80`, Caddy is listening on IPv4 all local interfaces. The next split is:

```bash
curl -v -H 'Host: radarr.wolf.den' http://192.168.137.253/
```

If that works on floki but Windows still gets `Connection refused`, stop changing Caddy. The remaining block is outside Caddy: host firewall rules, Proxmox/VM bridge rules, router ACLs, Windows network profile/firewall, or the client not actually being on the same reachable subnet.

Also make sure the browser is using plain HTTP, not HTTPS:

```text
http://radarr.wolf.den/
```

This stack is configured as internal HTTP. Do not use `https://radarr.wolf.den/` unless you deliberately add TLS later.

The download client settings do not change in any option. The Arr apps should still connect to native NZBGet at `172.18.0.1:6789` with download-client `Url Base` blank.

If your Caddy server is external on `192.168.137.251`, use:

```text
caddy/Caddyfile.external-192.168.137.251.example
```

For the current `wolf.den` setup on `192.168.137.253`, use:

```text
caddy/Caddyfile.external-wolf.den.example
```

In that file, replace `ARR_STACK_IP` with the Debian server IP that runs Docker and NZBGet. If Caddy runs on the same Debian server as the stack, use `127.0.0.1`.

First confirm whether native Caddy is installed on the Caddy server:

```bash
systemctl status caddy --no-pager
command -v caddy
```

If `systemctl` says `Unit caddy.service not found`, native Caddy is not installed as a Debian service yet. Install the official Caddy Debian package:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

After that, `systemctl status caddy` should work.

Then install this project's Caddyfile. Run this from the cloned GitHub repo, not from `/etc/caddy` or `/opt/media-stack`.

For the current `wolf.den` setup:

```bash
cd /tmp/arr-media-stack-debian
git pull
ls -l caddy/Caddyfile.external-wolf.den.example
sudo cp caddy/Caddyfile.external-wolf.den.example /etc/caddy/Caddyfile
ARR_STACK_IP="PUT_THE_DEBIAN_ARR_STACK_IP_HERE"
sudo sed -i "s/ARR_STACK_IP/${ARR_STACK_IP}/g" /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

For the older `media.home.arpa` example:

```bash
cd /tmp/arr-media-stack-debian
git pull
ls -l caddy/Caddyfile.external-192.168.137.251.example
sudo cp caddy/Caddyfile.external-192.168.137.251.example /etc/caddy/Caddyfile
ARR_STACK_IP="PUT_THE_DEBIAN_ARR_STACK_IP_HERE"
sudo sed -i "s/ARR_STACK_IP/${ARR_STACK_IP}/g" /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

If `ls` says the file does not exist, you are either in the wrong folder or the repo is old. Find the repo copy with:

```bash
sudo find /tmp /opt /root "$HOME" -path '*/caddy/Caddyfile.external-wolf.den.example' -type f 2>/dev/null
sudo find /tmp /opt /root "$HOME" -path '*/caddy/Caddyfile.external-192.168.137.251.example' -type f 2>/dev/null
```

If nothing is returned, download a fresh copy:

```bash
cd /tmp
rm -rf arr-media-stack-debian
git clone https://github.com/DisturbedMind/arr-media-stack-debian.git
cd /tmp/arr-media-stack-debian
```

Replace `PUT_THE_DEBIAN_ARR_STACK_IP_HERE` with the real Debian ARR stack IP before running it. If Caddy and the ARR stack are on the same Debian machine, use this instead:

```bash
sudo sed -i 's/ARR_STACK_IP/127.0.0.1/g' /etc/caddy/Caddyfile
```

For the older `media.home.arpa` example, point these LAN DNS names to `192.168.137.251`:

```text
radarr.media.home.arpa
sonarr.media.home.arpa
lidarr.media.home.arpa
whisparrv3.media.home.arpa
whisparrv2.media.home.arpa
nzbget.media.home.arpa
```

Then browse to:

```text
Radarr:      http://radarr.media.home.arpa/
Sonarr:      http://sonarr.media.home.arpa/
Lidarr:      http://lidarr.media.home.arpa/
Whisparr v3: http://whisparrv3.media.home.arpa/
Whisparr v2: http://whisparrv2.media.home.arpa/
NZBGet:      http://nzbget.media.home.arpa/
```

With this external Caddy layout, keep all Arr `URL Base` fields blank.

Do not use `172.18.0.1` in the external Caddyfile. `172.18.0.1` is only for Docker containers talking back to native NZBGet. Your external Caddy server must proxy to the Debian server LAN IP.

If Caddy fails with `bind: cannot assign requested address`, the Caddyfile is trying to listen on an IP address that the Caddy machine does not own. Check the server IPs:

```bash
ip -br addr
```

For this guide's external hostname Caddyfile, the best fix is to remove any `bind 192.168.137.x` lines:

```bash
sudo sed -i '/^[[:space:]]*bind 192\\.168\\.137\\./d' /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

If you really want to bind Caddy to one IP only, that IP must appear in `ip -br addr` on the Caddy server. For example, do not bind to `192.168.137.253` if the server is actually `192.168.137.251`.

If restarting Caddy shows port `80` is already owned by `docker-proxy`, the internal Docker Caddy container is still running. Stop and remove it:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep ':80->'
cd /opt/media-stack
docker compose stop caddy
docker compose rm -f caddy
sudo systemctl restart caddy
```

If the container was created outside Compose, remove it by name:

```bash
docker stop caddy
docker rm caddy
sudo systemctl restart caddy
```

If `systemctl restart caddy` still says `Unit caddy.service not found`, do not keep retrying restart. Install native Caddy with the commands above, or manage Caddy as a Docker container instead. This guide's external Caddy option assumes native Caddy on the server at `192.168.137.251`.

On the Debian ARR stack server, allow the Caddy server to reach the app ports:

```bash
sudo ufw allow from 192.168.137.253 to any port 7878 proto tcp
sudo ufw allow from 192.168.137.253 to any port 8989 proto tcp
sudo ufw allow from 192.168.137.253 to any port 8686 proto tcp
sudo ufw allow from 192.168.137.253 to any port 6969 proto tcp
sudo ufw allow from 192.168.137.253 to any port 6970 proto tcp
sudo ufw allow from 192.168.137.253 to any port 6789 proto tcp
sudo ufw reload
```

If you do not want LAN DNS names and Caddy really runs on a different IP from the ARR stack, you can use the port-mirror example instead:

```text
caddy/Caddyfile.external-port-mirror-192.168.137.251.example
```

That gives you URLs like `http://192.168.137.251:7878/`, but do not use it if Caddy and the ARR stack are on the same host/IP, because the ports will conflict.

The internal Docker Caddy service is included but disabled by default through a Compose profile:

```text
compose/native-nzbget.yml
```

Normal stack startup does not start it:

```bash
docker compose up -d
```

To start the internal Docker Caddy service anyway:

```bash
docker compose --profile internal-caddy up -d caddy
```

The Caddy config is:

```text
caddy/Caddyfile
```

That file is the path-based Caddy config. A no-URL-Base hostname example is also included here:

```text
caddy/Caddyfile.hostnames.example
```

For an already-running external Caddy server at `192.168.137.251`, prefer:

```text
caddy/Caddyfile.external-192.168.137.251.example
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

Start internal Docker Caddy:

```bash
cd /opt/media-stack
docker compose --profile internal-caddy up -d caddy
docker compose logs --tail=100 caddy
```

Validate that Caddy is listening:

```bash
docker compose ps caddy
curl -I http://127.0.0.1/
```

If you choose Option A, use these browser URLs:

```text
Radarr:      http://DEBIAN_SERVER_IP/radarr/
Sonarr:      http://DEBIAN_SERVER_IP/sonarr/
Lidarr:      http://DEBIAN_SERVER_IP/lidarr/
Whisparr v3: http://DEBIAN_SERVER_IP/whisparrv3/
Whisparr v2: http://DEBIAN_SERVER_IP/whisparrv2/
NZBGet:      http://DEBIAN_SERVER_IP/nzbget/
```

Test the path routes from Debian:

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

For Option A only, set URL Base inside each Arr app:

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
docker compose restart radarr sonarr lidarr whisparrv3 whisparrv2
docker compose --profile internal-caddy restart caddy
```

Important: these Arr URL Base settings are only for browser access through path-based Caddy. They are not download-client settings.

Once you set an Arr `URL Base`, plain direct-port access without that base path will no longer behave correctly. Use these direct-port URLs instead:

```text
Radarr:      http://DEBIAN_SERVER_IP:7878/radarr/
Sonarr:      http://DEBIAN_SERVER_IP:8989/sonarr/
Lidarr:      http://DEBIAN_SERVER_IP:8686/lidarr/
Whisparr v3: http://DEBIAN_SERVER_IP:6969/whisparrv3/
Whisparr v2: http://DEBIAN_SERVER_IP:6970/whisparrv2/
```

If you want the simple direct-port URLs to keep working, leave every Arr `URL Base` blank and skip the path-based Caddy URLs. You can still use direct ports, or switch to hostname-based Caddy with `caddy/Caddyfile.hostnames.example` and LAN DNS/hosts entries pointing those names to `DEBIAN_SERVER_IP`.

NZBGet is native on Debian and does not need to know about Caddy for the Arr apps to work. Caddy proxies `/nzbget/` to:

```text
172.18.0.1:6789
```

If your Docker network gateway is different, update the `reverse_proxy` line in `/opt/media-stack/caddy/Caddyfile` using:

If this command says `network media not found`, run `docker compose up -d` from `/opt/media-stack` first. The `media` network is created by Docker Compose.

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

Useful internal Docker Caddy commands:

```bash
cd /opt/media-stack
docker compose --profile internal-caddy up -d caddy
docker compose logs -f caddy
docker compose --profile internal-caddy restart caddy
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

Do not put an Arr `URL Base` value into the NZBGet download-client form. These are separate settings with annoyingly similar names:

```text
Arr app Settings -> General -> URL Base:
Only needed for path-based Caddy browser access.

Arr app Settings -> Download Clients -> NZBGet -> Url Base:
Keep blank for this native NZBGet setup.
```

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
- [Hostname Caddyfile example](caddy/Caddyfile.hostnames.example)
- [Wolf Den external Caddy example](caddy/Caddyfile.external-wolf.den.example)
- [External Caddy on 192.168.137.251 example](caddy/Caddyfile.external-192.168.137.251.example)
- [External Caddy port-mirror example](caddy/Caddyfile.external-port-mirror-192.168.137.251.example)
- [Env example](examples/media-stack.env.example)
- [SMB fstab example](examples/fstab-smb-example.txt)
- [Native NZBGet notes](outputs/native-nzbget-arr-troubleshooting.md)
- [ZIP bundle](outputs/debian-hotio-media-stack-pack.zip)







