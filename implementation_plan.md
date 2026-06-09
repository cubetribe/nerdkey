# Implementation Plan

Request feedback: true

## Goal

Deploy NerdKey CE production to `https://keys.nerdsmiths.de` with valid TLS and green health while preserving the existing Keygen account and Ed25519 signing material already embedded in the SDKs and shop.

Continuity target:

- Account ID: `6ff939de-b619-496f-ba99-e59bf64349e4`
- Ed25519 public key: `NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==`

## Decisions

- Migrate the existing local Keygen database instead of creating a fresh production account.
- Copy the matching Rails/ActiveRecord encryption secrets from local `.env` to production `.env`; otherwise encrypted signing material in the DB cannot be decrypted.
- Use Keygen CE via `keygen/api:v1.6`.
- Keep Caddy local-dev only. Production TLS terminates at the existing server NGINX.
- Use a production Compose file without Caddy and bind Keygen web to a loopback port, currently planned as `127.0.0.1:3055:3000`.
- Keep production secrets, dumps, and backups out of Git and only on server-managed paths.
- Do not change SDK default URLs or shop environment in this task.
- Do not run production DB restore, certbot issuance, NGINX reload, or mutating smoke tests without explicit Dennis approval.

## Preflight Findings

- Current local branch is `feat/l3-client-sdk`; requested branch `feat/prod-deploy` does not exist locally or on origin.
- Current dirty state includes this planning work and untracked `kit/swift/Package.resolved`.
- DNS for `keys.nerdsmiths.de` resolves to `5.182.17.148`.
- Server SSH access works via `vibe-coding` (`root`, port `2222`); hostname is `vmd185639`.
- NGINX is `1.24.0 (Ubuntu)` and syntax currently passes.
- No `keys.nerdsmiths.de` NGINX vHost or Let's Encrypt certificate exists.
- Current `keys.nerdsmiths.de` HTTPS serves the default `mangoblauai.dennis-westermann.de` certificate and fails hostname verification.
- Docker Server is `29.4.1`; Docker Compose is `v5.1.3`.
- `/opt/nerdkey` does not exist.
- Candidate loopback port `3055` was free during recon and must be checked again immediately before startup.

## Build Steps After Approval

1. Resolve the branch gate by creating or switching to `feat/prod-deploy` from the approved base.
2. Add `docker-compose.prod.yml`:
   - services: `web`, `worker`, `postgres`, `redis`
   - no Caddy
   - `web` published as `127.0.0.1:3055:3000`
   - persistent volumes for Keygen, Postgres, and Redis
   - production restart policies and health checks where appropriate
3. Add `config/nginx/keys.nerdsmiths.de.conf.example`:
   - HTTP ACME challenge path using `/var/www/html`
   - HTTP redirect to HTTPS after certificate issuance
   - HTTPS server block using `/etc/letsencrypt/live/keys.nerdsmiths.de/`
   - reverse proxy to `http://127.0.0.1:3055`
   - standard proxy headers and conservative security headers
4. Add `docs/production-rollout.md`:
   - branch/worktree preflight
   - secret migration rules
   - local dump creation and checksum
   - server directory layout
   - DB restore gate
   - NGINX/TLS steps
   - validation commands and expected evidence
   - cron backup setup and restore drill notes
   - rollback procedure
5. Update `.env.example` with production-safe comments only:
   - `KEYGEN_HOST=keys.nerdsmiths.de`
   - `NERDKEY_BASE_URL=https://keys.nerdsmiths.de`
   - `NERDKEY_TLS_VERIFY=true`
   - non-disabled `RACK_ATTACK_MAX_RPS` and `RACK_ATTACK_MAX_RPM`
6. Update `README.md` to link the production rollout doc and clarify Caddy vs NGINX roles.
7. Update `CHANGELOG.md` under `[Unreleased]` with release classification `minor`.

## Server Execution After Separate Approval

1. Create a fresh local DB dump from the local Keygen database with `scripts/backup-db.sh` and record checksum.
2. Copy repo files to `/opt/nerdkey` on `vmd185639`.
3. Copy local `.env` secret values to `/opt/nerdkey/.env`, changing only production host/TLS/rate-limit values:
   - `KEYGEN_HOST=keys.nerdsmiths.de`
   - `NERDKEY_BASE_URL=https://keys.nerdsmiths.de`
   - `NERDKEY_TLS_VERIFY=true`
   - `KEYGEN_EDITION=CE`
   - `KEYGEN_MODE=singleplayer`
   - rate limiting enabled with non-`-1` values
4. Copy the DB dump to a server-managed backup path.
5. Start Postgres and Redis only.
6. Restore the DB dump before first Keygen web/worker start, after destructive restore approval.
7. Start Keygen web and worker.
8. Add the NGINX vHost and request a Let's Encrypt HTTP-01 certificate.
9. Reload NGINX only after `nginx -t` passes.
10. Validate public health, TLS, account/public-key continuity, license issue/validate, seat-limit behavior, revoke, and backup schedule.

## Validation

Local validation:

1. `docker compose -f docker-compose.prod.yml config --quiet`
2. `python3 -m py_compile scripts/nerdkey.py`
3. `bash -n scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh`
4. `shellcheck scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh` if available

Production validation evidence:

1. `curl -fsS http://127.0.0.1:3055/v1/health`
2. `curl -fsS https://keys.nerdsmiths.de/v1/health`
3. TLS certificate subject/SAN for `keys.nerdsmiths.de`
4. `scripts/nerdkey health` against `https://keys.nerdsmiths.de` with TLS verification enabled
5. `scripts/nerdkey account public-key --json` confirms unchanged Ed25519 key
6. License issue and validate against production
7. Machine activation seats 1 and 2 succeed; seat 3 fails
8. Smoke license is revoked
9. Production DB backup is scheduled and a backup command succeeds

## Rollback

- Before cutover: stop the NerdKey compose project, disable the new NGINX vHost, run `nginx -t`, reload NGINX.
- After cutover: remove public traffic first through NGINX, preserve Docker volumes and dumps for inspection, and perform any DB restore only after a new explicit destructive approval.
- Never rotate or regenerate Keygen encryption secrets as part of rollback.

## Approval Gate

Stop here until Dennis approves the next phase.

Minimum approval needed to continue with repo edits:

`Dennis approves repo edits on feat/prod-deploy limited to the Phase 2 write-scope matrix, and approves creating local branch feat/prod-deploy from the current checked-out state.`
