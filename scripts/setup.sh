#!/usr/bin/env bash
# Prepare a Linux host (Debian/Ubuntu) for running the platform.
# Usage: setup.sh [--check-only] [--install-docker]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK_ONLY=false
INSTALL_DOCKER=false
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    --install-docker) INSTALL_DOCKER=true ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

check_os() {
  [[ "$(uname -s)" == "Linux" ]] || die "Linux is required"
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null && log "OS: ${PRETTY_NAME:-unknown}"
}

check_resources() {
  local mem_mb disk_gb
  mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  disk_gb=$(df -BG --output=avail "$REPO_ROOT" | tail -1 | tr -dc '0-9')
  log "Memory: ${mem_mb} MB, free disk: ${disk_gb} GB"
  (( mem_mb >= 2048 )) || warn "Less than 2 GB RAM - the ELK stack will not fit"
  (( disk_gb >= 10 ))  || warn "Less than 10 GB free disk"
}

check_tools() {
  local missing=0
  for t in git curl docker; do
    if command -v "$t" >/dev/null; then log "found $t: $($t --version 2>&1 | head -1)"
    else warn "missing $t"; missing=1; fi
  done
  return $missing
}

install_docker() {
  [[ $EUID -eq 0 ]] || die "--install-docker must run as root (use sudo)"
  require_cmd apt-get
  log "Installing Docker Engine + Compose plugin from the official repository"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

prepare_env() {
  mkdir -p "$REPO_ROOT/backups" "$REPO_ROOT/logs"
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$REPO_ROOT/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    # Replace placeholder secrets with random values so no default password is ever used.
    for key in POSTGRES_PASSWORD GRAFANA_ADMIN_PASSWORD; do
      sed -i "s|^${key}=.*|${key}=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)|" "$ENV_FILE"
    done
    log "Created $ENV_FILE with generated passwords (chmod 600)"
  else
    log "$ENV_FILE already exists - leaving it unchanged"
  fi
}

check_os
check_resources
if $INSTALL_DOCKER && ! $CHECK_ONLY; then install_docker; fi
if ! check_tools; then warn "Some tools are missing (re-run with --install-docker as root for Docker)"; fi
$CHECK_ONLY || prepare_env
log "Setup complete"
