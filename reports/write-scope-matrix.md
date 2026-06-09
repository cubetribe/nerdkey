# Write Scope Matrix

## Phase 2 Decision

NerdKey production deployment is approved for planning only. Implementation remains blocked until Dennis explicitly approves the repo edit gate and the later server mutation gates.

Current workspace facts:

- Workspace root: `/Volumes/2TB_CodingProjekte/Coding_Projekte/NerdKey`
- Current branch: `feat/l3-client-sdk`
- Requested deployment branch: `feat/prod-deploy`
- Existing dirty state: `reports/intake-brief.md` modified by Phase 1, untracked `kit/swift/Package.resolved`

## Proposed Repo Write Scope After Approval

| Path | Owner | Purpose | Risk |
| --- | --- | --- | --- |
| `docker-compose.prod.yml` | runtime_platform | Production Compose stack for Keygen `web`, `worker`, Postgres, and Redis only; bind Keygen web to `127.0.0.1:3055:3000`; no Caddy in production | Medium |
| `config/nginx/keys.nerdsmiths.de.conf.example` | runtime_platform | NGINX vHost template for `keys.nerdsmiths.de`, ACME HTTP-01 path, TLS config paths, and reverse proxy to `127.0.0.1:3055` | Medium |
| `docs/production-rollout.md` | docs_dx | Operator runbook covering migration, secrets, DB restore gate, TLS, validation, backup, rollback, and evidence capture | Medium |
| `.env.example` | runtime_platform | Production-safe comments/hints for `KEYGEN_HOST=keys.nerdsmiths.de`, `NERDKEY_BASE_URL=https://keys.nerdsmiths.de`, `NERDKEY_TLS_VERIFY=true`, and non-disabled rate limiting | Low |
| `README.md` | docs_dx | Link production runbook and clarify local Caddy vs production NGINX responsibility | Low |
| `CHANGELOG.md` | scribe | `[Unreleased]` entry for production deployment documentation/config; release classification `minor` | Low |
| `reports/intake-brief.md` | workflow_design | Phase 1 recon handoff and server facts | Low |
| `reports/write-scope-matrix.md` | workflow_design | Phase 2 bounded scope and gate record | Low |
| `implementation_plan.md` | workflow_design | User-gated execution plan for production rollout | Low |
| `task.md` | workflow_design | Post-approval checklist only after user gate opens | Low |
| `walkthrough.md` | scribe | Final closeout report after quality gates and production validation | Low |

## Denied Scope

- `.env`, `.env.*`, secret values, database dumps, generated license files, private keys, signing material, tokens
- SDK constants or default base URLs
- Shop `.env.backend` or shop integration
- Stripe, webhook, client-SDK wiring, platform signing, or auto-update work
- Version bumps or releases
- Git commit, push, force-push, or history rewrite
- Production DB drop/restore, NGINX reload, certbot issuance, or Docker state changes without explicit Dennis approval

## Server Mutation Scope After Separate Approval

Allowed only after the matching explicit gate:

1. Create `/opt/nerdkey` and server-managed backup directories.
2. Copy production-safe repo files and server-only `.env`/DB dump to the server.
3. Start Postgres and Redis.
4. Restore the migrated DB before first Keygen `web` start.
5. Start Keygen `web` and `worker`.
6. Add and enable the `keys.nerdsmiths.de` NGINX vHost.
7. Request a Let's Encrypt certificate for `keys.nerdsmiths.de`.
8. Reload NGINX after `nginx -t` passes.
9. Run production health and continuity validation.
10. Configure scheduled production DB backup.

## Approval Gates

| Gate | Required approval |
| --- | --- |
| Repo edit gate | Dennis approves repo edits on `feat/prod-deploy` limited to this write-scope matrix. |
| Branch gate | Dennis approves creating local branch `feat/prod-deploy` from the current checked-out state, or provides a different base. |
| Secret transfer gate | Dennis approves copying the existing local NerdKey `.env` secret values to `/opt/nerdkey/.env` on `vmd185639`. |
| Dump transfer gate | Dennis approves creating and copying a fresh local Keygen DB dump to `/opt/nerdkey/backups/` on `vmd185639`. |
| NGINX/TLS gate | Dennis approves adding the `keys.nerdsmiths.de` NGINX vHost and requesting a Let's Encrypt certificate. |
| Destructive restore gate | Dennis approves replacing the production NerdKey database from a named dump on `vmd185639`. |
| Mutating smoke gate | Dennis approves running production smoke validation that creates, activates, and revokes a test license. |
| Public cutover gate | Dennis approves treating `https://keys.nerdsmiths.de` as live production after evidence is collected. |

## Dependency Flow

1. Resolve branch/worktree state.
2. Add production docs/config artifacts.
3. Validate repo artifacts locally.
4. Produce fresh local DB dump and checksum.
5. Transfer repo, `.env` secrets, and dump to server only after approval.
6. Bring up production database dependencies.
7. Restore DB with matching encryption secrets before first app start.
8. Start Keygen app/worker.
9. Configure NGINX/TLS.
10. Validate public health, account/public-key continuity, license flow, seat-limit enforcement, backup schedule, and evidence report.

## Validation Gates

Local:

- `git status --short --branch`
- `docker compose -f docker-compose.prod.yml config --quiet`
- `python3 -m py_compile scripts/nerdkey.py`
- `bash -n scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh`
- `shellcheck scripts/nerdkey scripts/init-env.sh scripts/backup-db.sh scripts/restore-db.sh` when available

Production:

- `ss -ltnp` confirms `127.0.0.1:3055` is used only by NerdKey after startup
- `docker compose -f docker-compose.prod.yml ps`
- `curl -fsS http://127.0.0.1:3055/v1/health`
- `nginx -t`
- `curl -fsS https://keys.nerdsmiths.de/v1/health`
- TLS certificate subject/SAN includes `keys.nerdsmiths.de`
- `scripts/nerdkey account public-key --json` against production returns the unchanged Ed25519 key
- Production smoke shows two seats accepted and the third rejected, then revokes the smoke license
- Production DB backup schedule exists and a backup command succeeds
