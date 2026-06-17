# Debian 12.11 hotio media stack guide

This recreated guide captures the working setup from this chat.

## Media shares

Windows host:

```text
192.168.137.110
```

Shares:

```text
\\192.168.137.110\cinema\movies
\\192.168.137.110\cinema\series
\\192.168.137.110\cinema\music
\\192.168.137.110\adult\movies
\\192.168.137.110\adult\adultseries
```

Mount share roots on Debian:

```text
//192.168.137.110/cinema -> /mnt/media/cinema
//192.168.137.110/adult  -> /mnt/media/adult
```

Use [fstab-smb-example.txt](<C:\Codex\Projects\Docker ARR Media Stack\outputs\fstab-smb-example.txt>) for the fstab entries.

## Container layout

App config should stay on Debian:

```text
/opt/media-stack/appdata/radarr
/opt/media-stack/appdata/sonarr
/opt/media-stack/appdata/lidarr
/opt/media-stack/appdata/whisparr-v3
/opt/media-stack/appdata/whisparr-v2
```

Media stays on the Windows shares mounted under `/mnt/media`.

## Compose files

Two Compose variants are restored:

```text
[media-stack-compose-docker-nzbget.yml](<C:\Codex\Projects\Docker ARR Media Stack\outputs\media-stack-compose-docker-nzbget.yml>)
[media-stack-compose-native-nzbget.yml](<C:\Codex\Projects\Docker ARR Media Stack\outputs\media-stack-compose-native-nzbget.yml>)
```

Use the native-NZBGet variant if NZBGet is installed directly on Debian. It gives every Arr container both path styles:

```text
/data/cinema
/data/adult
/mnt/media/cinema
/mnt/media/adult
```

That makes remote path mappings easier.

## Native NZBGet notes

If NZBGet is installed directly on Debian:

```text
Arr Host: host.docker.internal
Port: 6789
Use SSL: no
Url Base: blank
```

The firewall must allow Docker bridge traffic to NZBGet:

```bash
sudo ufw allow in on docker0 to any port 6789 proto tcp
sudo ufw reload
```

See [native-nzbget-arr-troubleshooting.md](<C:\Codex\Projects\Docker ARR Media Stack\outputs\native-nzbget-arr-troubleshooting.md>) for the exact troubleshooting notes from the chat.

## Whisparr v3

Whisparr v3 is fussier than Radarr for imports. Its import screen expects an import/staging folder, for example:

```text
/mnt/media/adult/movies/import
```

Test imports in small batches before moving a large library.
