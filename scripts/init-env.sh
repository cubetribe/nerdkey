#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env && "${1:-}" != "--force" ]]; then
  printf '.env already exists. Use %s --force to replace it.\n' "$0" >&2
  exit 73
fi

if [[ ! -f .env.example ]]; then
  printf '.env.example not found. Run this script from the repo root.\n' >&2
  exit 66
fi

account_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
postgres_password=$(openssl rand -hex 16)
secret_key_base=$(openssl rand -hex 64)
encryption_deterministic_key=$(openssl rand -base64 32)
encryption_primary_key=$(openssl rand -base64 32)
encryption_key_derivation_salt=$(openssl rand -base64 32)
admin_email=${KEYGEN_ADMIN_EMAIL:-admin@nerdsmiths.local}
admin_password=${KEYGEN_ADMIN_PASSWORD:-$(openssl rand -hex 16)}

cp .env.example .env

set_value() {
  local key=$1
  local value=$2
  python3 - "$key" "$value" <<'PY'
from pathlib import Path
import sys

key = sys.argv[1]
value = sys.argv[2]
path = Path(".env")
lines = path.read_text(encoding="utf-8").splitlines()
for index, line in enumerate(lines):
    if line.startswith(f"{key}="):
        lines[index] = f"{key}={value}"
        break
else:
    lines.append(f"{key}={value}")
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

set_value POSTGRES_PASSWORD "$postgres_password"
set_value SECRET_KEY_BASE "$secret_key_base"
set_value ENCRYPTION_DETERMINISTIC_KEY "$encryption_deterministic_key"
set_value ENCRYPTION_PRIMARY_KEY "$encryption_primary_key"
set_value ENCRYPTION_KEY_DERIVATION_SALT "$encryption_key_derivation_salt"
set_value KEYGEN_ACCOUNT_ID "$account_id"
set_value KEYGEN_ADMIN_EMAIL "$admin_email"
set_value KEYGEN_ADMIN_PASSWORD "$admin_password"

cat <<MSG
Created .env with generated local secrets.

Admin email:    $admin_email
Admin password: $admin_password
Account ID:     $account_id

Next:
  docker compose --profile setup run --rm setup
  docker compose up -d
  python3 scripts/nerdkey.py token issue --save
MSG
