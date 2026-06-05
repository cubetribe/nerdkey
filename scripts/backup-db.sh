#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s backups/nerdkey-YYYYmmddHHMMSS.dump\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

output=$1
mkdir -p "$(dirname "$output")"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

if [[ -f "$output" ]]; then
  printf 'Refusing to overwrite existing backup: %s\n' "$output" >&2
  exit 73
fi

docker compose exec -T postgres pg_dump \
  --username "${POSTGRES_USER:-keygen}" \
  --dbname "${POSTGRES_DB:-keygen}" \
  --format custom \
  --no-owner \
  --no-acl > "$output"

printf 'Backup written: %s\n' "$output"
