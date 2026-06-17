#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="${STACK_DIR:-/opt/media-stack}"
STACK_USER="${STACK_USER:-${SUDO_USER:-$USER}}"
START_STACK=0

usage() {
  cat <<'USAGE'
Install/stage the Docker ARR Media Stack on Debian.

Usage:
  scripts/install-debian.sh [--start]

Options:
  --start   Run "docker compose up -d" after staging files.

Environment:
  STACK_DIR=/opt/media-stack   Install target.
  STACK_USER=<user>            Owner for /opt/media-stack files.

This script installs required Debian packages, Docker Engine if missing,
native NZBGet, and stages compose/Caddy/example files. It does not write your
SMB password or edit /etc/fstab automatically.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)
      START_STACK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f /etc/debian_version ]]; then
  echo "This installer is intended for Debian 12.x." >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

echo "==> Installing base packages"
run_sudo apt update
run_sudo apt install -y ca-certificates curl gnupg cifs-utils acl nano unzip p7zip-full 7zip ffmpeg

echo "==> Installing unrar if available"
if ! run_sudo apt install -y unrar; then
  cat >&2 <<'WARN'

WARNING: apt could not install "unrar".
On Debian 12 Bookworm, enable contrib/non-free/non-free-firmware in /etc/apt/sources.list, then run:

  sudo apt update
  sudo apt install -y unrar

Missing unrar can make good NZBs download to 100% and fail immediately.
WARN
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker Engine from Docker's official Debian repository"
  run_sudo install -m 0755 -d /etc/apt/keyrings
  run_sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  run_sudo chmod a+r /etc/apt/keyrings/docker.asc
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"
  tmp_sources="$(mktemp)"
  cat > "${tmp_sources}" <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  run_sudo install -m 0644 "${tmp_sources}" /etc/apt/sources.list.d/docker.sources
  rm -f "${tmp_sources}"
  run_sudo apt update
  run_sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run_sudo systemctl enable --now docker
else
  echo "==> Docker is already installed"
fi

if ! id -nG "${STACK_USER}" | grep -qw docker; then
  echo "==> Adding ${STACK_USER} to docker group"
  run_sudo usermod -aG docker "${STACK_USER}"
  echo "NOTE: ${STACK_USER} must log out and back in before docker works without sudo."
fi

if ! command -v nzbget >/dev/null 2>&1; then
  echo "==> Installing native NZBGet"
  run_sudo install -m 0755 -d /etc/apt/keyrings
  run_sudo curl -fsSL https://nzbgetcom.github.io/nzbgetcom.asc -o /etc/apt/keyrings/nzbgetcom.asc
  run_sudo chmod a+r /etc/apt/keyrings/nzbgetcom.asc
  echo "deb [arch=all signed-by=/etc/apt/keyrings/nzbgetcom.asc] https://nzbgetcom.github.io/deb stable main" | run_sudo tee /etc/apt/sources.list.d/nzbgetcom.list >/dev/null
  run_sudo apt update
  run_sudo apt install -y nzbget
  run_sudo systemctl enable --now nzbget
else
  echo "==> NZBGet is already installed"
fi

echo "==> Creating media-stack folders"
run_sudo mkdir -p "${STACK_DIR}/appdata"/{radarr,sonarr,lidarr,whisparr-v3,whisparr-v2}
run_sudo mkdir -p "${STACK_DIR}/backups" "${STACK_DIR}/caddy/data" "${STACK_DIR}/caddy/config"
run_sudo mkdir -p /mnt/media/cinema /mnt/media/adult

echo "==> Staging compose, env example, Caddyfile, and fstab example"
run_sudo install -m 0644 "${REPO_DIR}/compose/native-nzbget.yml" "${STACK_DIR}/compose.yml"
if [[ ! -f "${STACK_DIR}/.env" ]]; then
  run_sudo install -m 0644 "${REPO_DIR}/examples/media-stack.env.example" "${STACK_DIR}/.env"
else
  echo "==> Keeping existing ${STACK_DIR}/.env"
fi
run_sudo install -m 0644 "${REPO_DIR}/caddy/Caddyfile" "${STACK_DIR}/caddy/Caddyfile"
run_sudo install -m 0644 "${REPO_DIR}/examples/fstab-smb-example.txt" "${STACK_DIR}/fstab-smb-example.txt"

uid="$(id -u "${STACK_USER}")"
gid="$(id -g "${STACK_USER}")"
run_sudo chown -R "${uid}:${gid}" "${STACK_DIR}"

echo "==> Verifying required tools"
command -v ffmpeg >/dev/null && ffmpeg -version | head -1 || true
command -v unrar >/dev/null && unrar | head -2 || true

cat <<NEXT

Install files are staged in:
  ${STACK_DIR}

Next manual steps:
  1. Create /etc/samba/media-stack.cred with the Windows share username/password.
  2. Add the fstab entries from ${STACK_DIR}/fstab-smb-example.txt to /etc/fstab.
  3. Run: sudo systemctl daemon-reload && sudo mount -a
  4. Confirm: findmnt /mnt/media/cinema && findmnt /mnt/media/adult
  5. Confirm NZBGet has ControlIP=0.0.0.0.
     Preferred: NZBGet Web UI -> Settings -> Security -> ControlIP.
     If editing by hand, locate the active config first:
       sudo systemctl show nzbget -p ExecStart --value
       ps -eo user,group,args | grep '[n]zbget'
       sudo find /etc /opt /var/lib /usr/local -iname 'nzbget.conf' -type f 2>/dev/null
     Do not create a blank /etc/nzbget.conf if it is not the active config.
  6. Allow firewall rules from the README.
NEXT

if [[ "${START_STACK}" -eq 1 ]]; then
  echo "==> Starting Docker stack"
  cd "${STACK_DIR}"
  if [[ "${EUID}" -eq 0 ]]; then
    docker compose up -d
  else
    docker compose up -d
  fi
else
  echo "Run this when the SMB mounts and NZBGet settings are ready:"
  echo "  cd ${STACK_DIR} && docker compose up -d"
fi
