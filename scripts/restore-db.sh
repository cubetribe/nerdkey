#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s backups/nerdkey.dump\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

input=$1
if [[ ! -f "$input" ]]; then
  printf 'Backup not found: %s\n' "$input" >&2
  exit 66
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

cat <<'MSG' >&2
This will replace the local Keygen database contents.
Set NERDKEY_RESTORE_CONFIRM=replace-local-db to continue.
MSG

if [[ "${NERDKEY_RESTORE_CONFIRM:-}" != "replace-local-db" ]]; then
  exit 78
fi

docker compose stop web worker >/dev/null

docker compose exec -T postgres dropdb \
  --username "${POSTGRES_USER:-keygen}" \
  --if-exists \
  "${POSTGRES_DB:-keygen}"

docker compose exec -T postgres createdb \
  --username "${POSTGRES_USER:-keygen}" \
  "${POSTGRES_DB:-keygen}"

docker compose exec -T postgres pg_restore \
  --username "${POSTGRES_USER:-keygen}" \
  --dbname "${POSTGRES_DB:-keygen}" \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl < "$input"

docker compose start web worker >/dev/null
printf 'Restore complete: %s\n' "$input"
