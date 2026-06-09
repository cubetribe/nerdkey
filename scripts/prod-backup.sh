#!/usr/bin/env bash
# Production DB backup for NerdKey (Keygen CE) on the server.
# Runs pg_dump through the prod compose project and keeps the latest N dumps.
# Intended to run from /opt/nerdkey via cron. Does NOT touch the migration dump
# (nerdkey-prodmigrate-*.dump) — retention only prunes auto-* dumps.
set -euo pipefail

cd /opt/nerdkey

COMPOSE_FILE=docker-compose.prod.yml
KEEP=14
ts=$(date +%Y%m%d%H%M%S)
out="backups/nerdkey-auto-${ts}.dump"

mkdir -p backups

# shellcheck disable=SC1091
if [[ -f .env ]]; then set -a; . ./.env; set +a; fi

docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump \
  --username "${POSTGRES_USER:-keygen}" \
  --dbname "${POSTGRES_DB:-keygen}" \
  --format custom \
  --no-owner \
  --no-acl > "$out"

chmod 600 "$out"

# Retention: keep only the newest $KEEP auto dumps.
ls -1t backups/nerdkey-auto-*.dump 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

printf 'backup: %s (%s bytes)\n' "$out" "$(wc -c < "$out")"
