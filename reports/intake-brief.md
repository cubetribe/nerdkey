# Intake Brief

## Request

Deploy NerdKey CE production to `https://keys.nerdsmiths.de` with valid TLS and green health, without invalidating the already embedded Keygen account ID or Ed25519 signing public key in the client SDKs and shop.

The required continuity target is:

- Account ID: `6ff939de-b619-496f-ba99-e59bf64349e4`
- Ed25519 public key: `NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==`

Default operator path: migrate the existing local Keygen database and preserve the local encryption secrets. Do not create a fresh production account unless the SDKs and shop will be deliberately re-embedded.

## Binding Inputs

- `AGENTS.md`
- `docs/BUILD_BRIEF.md`
- `docs/Nerdsmiths_Licensing_Standard.md`
- User prompt for production rollout
- Official Keygen self-hosting documentation: https://keygen.sh/docs/self-hosting/

Binding constraints:

- Use Keygen CE (`keygen/api:v1.6`); do not implement custom licensing crypto.
- Do not add Stripe, shop wiring, SDK default URL changes, platform signing, or auto-update work in this task.
- Never commit `.env`, database dumps, generated license files, private keys, tokens, or signing material.
- Restore/drop operations on production are hard-gated and require explicit Dennis approval.
- Release law: update `CHANGELOG.md` under `[Unreleased]` for user-facing repo changes and classify impact.

## Local Repository State

- Workspace root: `/Volumes/2TB_CodingProjekte/Coding_Projekte/NerdKey`.
- Current branch: `feat/l3-client-sdk`, not the requested `feat/prod-deploy`.
- Branches present locally/remotely: `main`, `feat/l3-client-sdk`; no `feat/prod-deploy` branch exists.
- Dirty state before this report: untracked `kit/swift/Package.resolved`.
- Local Docker Compose project is not running (`docker compose ps` returned no services).
- Local ignored dump present: `backups/nerdkey-test.dump`.
- `.env` exists and contains the required Keygen/Rails/Postgres secret variable names, including `SECRET_KEY_BASE`, `ENCRYPTION_DETERMINISTIC_KEY`, `ENCRYPTION_PRIMARY_KEY`, and `ENCRYPTION_KEY_DERIVATION_SALT`; values were not copied into this report.

## Repo Deployment Surface

- `docker-compose.yml` is currently local-dev oriented:
  - `web` publishes host port `3000:3000`.
  - `caddy` publishes host ports `80:80` and `443:443`.
  - Caddy uses `tls internal` via `compose/Caddyfile`.
- `.env.example` defaults to:
  - `KEYGEN_HOST=nerdkey.localhost`
  - `NERDKEY_BASE_URL=https://nerdkey.localhost`
  - `NERDKEY_TLS_VERIFY=false`
  - `RACK_ATTACK_MAX_RPS=-1`
  - `RACK_ATTACK_MAX_RPM=-1`
- `scripts/backup-db.sh` creates custom-format Postgres dumps through `docker compose exec -T postgres pg_dump`.
- `scripts/restore-db.sh` is destructive, requires `NERDKEY_RESTORE_CONFIRM=replace-local-db`, stops `web worker`, drops/recreates the DB, restores with `pg_restore`, and restarts `web worker`.
- `scripts/nerdkey smoke` mutates Keygen data: health, apply product, issue smoke license, activate 2 seats, validate, assert 3rd activation failure, list, revoke, print `PASS`.

## Server Recon

Target server access:

- DNS: `keys.nerdsmiths.de` resolves to `5.182.17.148`.
- SSH alias: `vibe-coding` reaches the same host as `root` on port `2222`.
- Hostname: `vmd185639`.

Current public behavior:

- `http://keys.nerdsmiths.de/v1/health` returns NGINX `301` to `https://mangoblauai.dennis-westermann.de/v1/health`.
- `https://keys.nerdsmiths.de/v1/health` fails hostname verification because the served certificate is for `mangoblauai.dennis-westermann.de`.
- Open public ports verified: `80`, `443`, and SSH on `2222`. Port `22` times out.

Server runtime:

- NGINX: `nginx/1.24.0 (Ubuntu)`.
- `nginx -T` reports syntax OK but existing 443 protocol-option warnings.
- No NGINX reference to `keys.nerdsmiths.de` was found under `/etc/nginx`.
- Current default NGINX server redirects unknown hosts to `mangoblauai.dennis-westermann.de`.
- Docker Server: `29.4.1`.
- Docker Compose: `v5.1.3`.
- Existing compose projects are numerous; no NerdKey/Keygen project exists.
- `/opt/nerdkey` does not exist.
- `certbot 2.9.0` is installed; `certbot.timer` is enabled and active.
- No Let's Encrypt certificate exists for `keys.nerdsmiths.de`.
- ACME webroot directories `/var/www/certbot` and `/var/www/html` exist.

Port observations:

- Server host ports already in use include many app ports such as `3001-3007`, `3013-3017`, `3020`, `3025`, `3100`, `3173`, `3180`, `3220`, `3301`, `4001`, `4567`, `8000`, `8002`, `8010`, `8080`, `8090-8092`, `18080`, `18081`, plus public `80/443/2222`.
- Candidate private Keygen host port for NGINX proxying: `127.0.0.1:3055` mapping to container `3000`, subject to a final `ss -ltnp` check immediately before applying.

## Risks And Gates

- Current branch mismatch must be resolved before repo edits intended for `feat/prod-deploy`.
- A fresh `scripts/init-env.sh` run on production would generate new account/secrets and break SDK/shop key continuity; do not use it as the production secret source.
- The local database dump must be restored with the matching local Rails encryption secrets, or Keygen will be unable to decrypt encrypted signing material in the DB.
- Production restore is destructive. It must be preceded by a production DB backup if any production DB exists and requires explicit Dennis approval.
- The current restore confirmation string is local-oriented (`replace-local-db`), so production use must be documented carefully or wrapped in an operator-specific command.
- Running the smoke test in production intentionally creates and revokes a smoke license; that mutation needs explicit approval.
- Caddy must remain local-dev only; production TLS should terminate at the existing NGINX.

## Recommended Next Phase

Design a bounded production deployment plan before any server mutation:

1. Create/switch to `feat/prod-deploy` locally after approval.
2. Add production-safe repo artifacts only: a production compose override or documented compose command, production runbook, backup cron documentation, NGINX vHost template/runbook, `.env.example` production hints, README/CHANGELOG/report updates.
3. Use `/opt/nerdkey` on the server, with `.env` and dumps copied only to server-managed ignored paths.
4. Bind Keygen web only to loopback, likely `127.0.0.1:3055:3000`; do not run Caddy in production.
5. Add an NGINX `keys.nerdsmiths.de` server block, obtain a certbot HTTP-01 certificate, proxy to the loopback Keygen port.
6. Restore the migrated DB before the first app start, then validate health, account ID/public key continuity, and seat-limit behavior against `https://keys.nerdsmiths.de`.
