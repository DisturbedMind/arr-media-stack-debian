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

## Caddy service not found

If this fails:

```bash
sudo systemctl restart caddy
```

with:

```text
Failed to restart caddy.service: Unit caddy.service not found.
```

then native Caddy is not installed as a Debian service on that machine. Install native Caddy first, or manage Caddy as a Docker container instead. For the external proxy at `192.168.137.251`, this guide expects native Caddy so `/etc/caddy/Caddyfile` and `systemctl reload caddy` work.

If copying the external Caddyfile fails with:

```text
cp: cannot stat 'caddy/Caddyfile.external-192.168.137.251.example': No such file or directory
```

you are not in the cloned repo folder, or the repo is old. Use:

```bash
cd /tmp/arr-media-stack-debian
git pull
ls -l caddy/Caddyfile.external-192.168.137.251.example
```

If that folder does not exist, clone it again:

```bash
cd /tmp
rm -rf arr-media-stack-debian
git clone https://github.com/DisturbedMind/arr-media-stack-debian.git
cd /tmp/arr-media-stack-debian
```

## Caddy cannot assign requested address

If Caddy fails with:

```text
bind: cannot assign requested address
```

then `/etc/caddy/Caddyfile` has a `bind` line for an IP address that is not on that Caddy server. Check:

```bash
ip -br addr
```

For the external hostname Caddyfile, remove the bind lines:

```bash
sudo sed -i '/^[[:space:]]*bind 192\\.168\\.137\\./d' /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

The DNS records should point to the Caddy server IP, but the Caddyfile does not need `bind 192.168.137.x` lines.

## Only one Caddy hostname works

For the current `wolf.den` setup, every DNS name must point to the Caddy server IP:

```text
radarr.wolf.den       -> 192.168.137.253
sonarr.wolf.den       -> 192.168.137.253
lidarr.wolf.den       -> 192.168.137.253
whisparrv3.wolf.den   -> 192.168.137.253
whisparrv2.wolf.den   -> 192.168.137.253
nzbget.wolf.den       -> 192.168.137.253
```

If `radarr.wolf.den` works but the others do not:

```bash
for app in radarr sonarr lidarr whisparrv3 whisparrv2 nzbget; do getent hosts "$app.wolf.den"; done
grep -E 'radarr|sonarr|lidarr|whisparrv3|whisparrv2|nzbget' /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo journalctl -u caddy -n 80 --no-pager
```

If DNS is correct and Caddy has all hostnames, test backend reachability from the Caddy server:

```bash
curl -I http://ARR_STACK_IP:7878
curl -I http://ARR_STACK_IP:8989
curl -I http://ARR_STACK_IP:8686
curl -I http://ARR_STACK_IP:6969
curl -I http://ARR_STACK_IP:6970
curl -I http://ARR_STACK_IP:6789
```

Replace `ARR_STACK_IP` with the Debian ARR stack IP, or use `127.0.0.1` if Caddy and the stack are on the same server.

## Browser says connection refused

If the browser says `connection refused` for `http://radarr.wolf.den`, the request is not reaching a working Caddy listener on port `80`.

Run this on the Caddy server:

```bash
getent hosts radarr.wolf.den
sudo systemctl status caddy --no-pager
sudo ss -ltnp | grep ':80'
sudo journalctl -u caddy -n 80 --no-pager
sudo ufw status verbose
```

Expected:

```text
radarr.wolf.den -> 192.168.137.253
caddy.service -> active/running
ss -> caddy listening on 0.0.0.0:80 or [::]:80
```

If Caddy is not running:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
sudo journalctl -u caddy -n 80 --no-pager
```

If Caddy is running but UFW blocks port `80`:

```bash
sudo ufw allow from 192.168.137.0/24 to any port 80 proto tcp
sudo ufw reload
```

If Caddy is running and `http://192.168.137.253` responds, but `http://radarr.wolf.den` does not, test Caddy without DNS:

```bash
curl -I -H 'Host: radarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: sonarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: lidarr.wolf.den' http://127.0.0.1
curl -I -H 'Host: whisparrv3.wolf.den' http://127.0.0.1
curl -I -H 'Host: whisparrv2.wolf.den' http://127.0.0.1
curl -I -H 'Host: nzbget.wolf.den' http://127.0.0.1
```

If those work on the Caddy server, the Caddyfile is good and the client DNS is the problem. On Windows, test:

```powershell
nslookup radarr.wolf.den
nslookup sonarr.wolf.den
Resolve-DnsName radarr.wolf.den
curl.exe -v --resolve radarr.wolf.den:80:192.168.137.253 http://radarr.wolf.den/
ipconfig /flushdns
```

Use `http://radarr.wolf.den/`, not `https://radarr.wolf.den/`, unless TLS has been configured.

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
