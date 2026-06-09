# Production Rollout — keys.nerdsmiths.de

How NerdKey CE is deployed to production at `https://keys.nerdsmiths.de`, and how
to repeat or roll it back. This is the procedure that was used for the initial
cutover on 2026-06-10.

## Topology

- **Host:** `vmd185639` (`5.182.17.148`), reached via the local SSH alias
  `vibe-coding` (`root`, port `2222`).
- **App:** Keygen CE `keygen/api:v1.6`, compose project under `/opt/nerdkey`,
  started with `docker-compose.prod.yml` (no Caddy).
- **Exposure:** `web` is bound to `127.0.0.1:3055` only. It is never published
  to the public internet directly.
- **TLS / routing:** the host NGINX terminates TLS for `keys.nerdsmiths.de` and
  reverse-proxies to `127.0.0.1:3055`. Caddy stays local-dev only.
- **Identity continuity (must not change):**
  - Account ID `6ff939de-b619-496f-ba99-e59bf64349e4`
  - Ed25519 public key (hex) `58a1ae3d48b96d679383b4d2c65bcaa1b8c335b17d9e07ff7951428224bb3fa6`
    (= the base64 value embedded in the SDKs)

The production account, signing keys, and licenses are **migrated from the local
Keygen database**. A fresh `scripts/init-env.sh` on the server would mint a new
account and break every embedded SDK — never use it as the production secret
source.

## Secrets rule

The Rails/ActiveRecord encryption secrets in production `.env` MUST be the same
values that encrypted the local database, or Keygen cannot decrypt the signing
material it restores:

- `SECRET_KEY_BASE`
- `ENCRYPTION_DETERMINISTIC_KEY`
- `ENCRYPTION_PRIMARY_KEY`
- `ENCRYPTION_KEY_DERIVATION_SALT`
- `POSTGRES_PASSWORD`, `KEYGEN_ACCOUNT_ID`, `KEYGEN_ADMIN_TOKEN`

These are copied from the local `.env`. The only values changed for production:

| Key | Production value |
| --- | --- |
| `KEYGEN_HOST` | `keys.nerdsmiths.de` |
| `NERDKEY_BASE_URL` | `https://keys.nerdsmiths.de` |
| `NERDKEY_TLS_VERIFY` | `true` |
| `RACK_ATTACK_MAX_RPS` | `20` (per-IP; tune as needed) |
| `RACK_ATTACK_MAX_RPM` | `600` (per-IP; tune as needed) |

`.env` and all DB dumps live only under `/opt/nerdkey` (mode `0700`, files
`0600`) and are never committed.

## Rollout procedure

### 1. Local — produce the migration dump

```bash
docker compose up -d postgres                       # local DB only
# verify continuity in the source DB:
docker compose exec -T postgres psql -U keygen -d keygen -c \
  "SELECT id, ed25519_public_key FROM accounts;"
./scripts/backup-db.sh backups/nerdkey-prodmigrate-$(date +%Y%m%d).dump
shasum -a 256 backups/nerdkey-prodmigrate-*.dump
```

### 2. Server — stage files

```bash
ssh vibe-coding 'mkdir -p /opt/nerdkey/backups && chmod 700 /opt/nerdkey /opt/nerdkey/backups'
rsync -av docker-compose.prod.yml products.yaml scripts config policies vibe-coding:/opt/nerdkey/
scp .env       vibe-coding:/opt/nerdkey/.env            # then chmod 600
scp backups/nerdkey-prodmigrate-*.dump vibe-coding:/opt/nerdkey/backups/
```

Apply the production `.env` overrides from the table above (e.g. `sed -i`),
then verify the dump checksum on the server matches local.

### 3. Server — database first, then app

```bash
cd /opt/nerdkey
docker compose -f docker-compose.prod.yml up -d postgres redis      # wait healthy
# restore the migrated DB into the fresh, empty database BEFORE web starts:
cat backups/nerdkey-prodmigrate-*.dump | docker compose -f docker-compose.prod.yml \
  exec -T postgres pg_restore -U keygen -d keygen --no-owner --no-acl
docker compose -f docker-compose.prod.yml up -d web worker
curl -fsS http://127.0.0.1:3055/v1/health
```

### 4. Server — NGINX + TLS (two phases)

Phase A — HTTP-only block so ACME can validate, then issue the cert:

```nginx
server {
    listen 80; listen [::]:80;
    server_name keys.nerdsmiths.de;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 404; }
}
```

```bash
ln -sf /etc/nginx/sites-available/keys.nerdsmiths.de.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot certonly --webroot -w /var/www/html -d keys.nerdsmiths.de \
  --non-interactive --agree-tos -m cubetribe@googlemail.com --no-eff-email
```

Phase B — swap in the full TLS vhost (see
`config/nginx/keys.nerdsmiths.de.conf.example`), then:

```bash
nginx -t && systemctl reload nginx
```

### 5. Validate (from outside)

```bash
curl -fsS https://keys.nerdsmiths.de/v1/health                       # 200
curl -sI  http://keys.nerdsmiths.de/v1/health | grep -i location     # 301 -> https
echo | openssl s_client -servername keys.nerdsmiths.de \
  -connect keys.nerdsmiths.de:443 2>/dev/null | openssl x509 -noout -subject -dates
```

Read-only continuity check (prints only the key, never the token):

```bash
cd /opt/nerdkey; set -a; . ./.env; set +a
curl -fsS -H "Authorization: Bearer $KEYGEN_ADMIN_TOKEN" \
  "https://keys.nerdsmiths.de/v1/accounts/$KEYGEN_ACCOUNT_ID/licenses?limit=5"
```

A mutating end-to-end smoke (`scripts/nerdkey smoke`) issues and revokes a test
license **and re-applies products** — only run it knowingly, since it can alter
the migrated product/policy that existing licenses depend on.

## Backups

Daily DB dump via cron (installed on the host):

```cron
30 3 * * * /opt/nerdkey/scripts/prod-backup.sh >> /var/log/nerdkey-backup.log 2>&1
```

`scripts/prod-backup.sh` writes `0600` `backups/nerdkey-auto-<ts>.dump` files,
keeps the newest 14, and never prunes the `nerdkey-prodmigrate-*` dump. Treat
all dumps as sensitive: they contain encrypted signing material and license data.

## Rollback

- **Before cutover:** `docker compose -f docker-compose.prod.yml down`, remove
  the `keys.nerdsmiths.de` symlink from `sites-enabled/`, `nginx -t`, reload.
- **After cutover:** remove public traffic at NGINX first (disable the vhost),
  preserve Docker volumes and dumps for inspection. Any DB restore is destructive
  and needs a fresh explicit approval.
- **Never** rotate or regenerate the Keygen encryption secrets during rollback —
  that permanently breaks decryption of the existing signing material.
