#!/usr/bin/env bash
# Shared helpers sourced by the other scripts. Not meant to be run directly.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$REPO_ROOT/docker/docker-compose.yml}"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"

_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()  { printf '%s [INFO ] %s\n'  "$(_ts)" "$*"; }
warn() { printf '%s [WARN ] %s\n'  "$(_ts)" "$*" >&2; }
err()  { printf '%s [ERROR] %s\n'  "$(_ts)" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

load_env() {
  [[ -f "$ENV_FILE" ]] || die "Missing $ENV_FILE - run scripts/setup.sh first"
  set -a; # shellcheck disable=SC1090
  source "$ENV_FILE"; set +a
}
