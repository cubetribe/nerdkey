# Write Scope Matrix

## Approved Implementation Scope After User Gate

| Path | Owner | Purpose | Risk |
| --- | --- | --- | --- |
| `AGENTS.md` | workspace_governance | Repo-local rules and phase boundaries | Low |
| `README.md` | docs_dx | Complete setup, smoke test, policy, key, backup/restore docs | Medium |
| `CHANGELOG.md` | scribe | `[Unreleased]` ledger | Low |
| `.gitignore` | workspace_governance | Secret, dump, key, and generated artifact exclusions | Low |
| `.env.example` | runtime_platform | Complete non-secret environment template | Medium |
| `docker-compose.yml` | runtime_platform | Keygen CE, Postgres, Redis, worker, local proxy | Medium |
| `compose/Caddyfile` | runtime_platform | Local TLS reverse proxy for `nerdkey.localhost` | Low |
| `products.yaml` | builder | Product registry and seat/policy single source of truth | Medium |
| `policies/products/nerdsmiths-demo.json` | builder | Generated/reference policy-as-code for a 2-seat perpetual product | Medium |
| `scripts/nerdkey.py` | builder | Thin `nerdkey` admin/smoke CLI over Keygen API and console bootstrap | High |
| `scripts/backup-db.sh` | quality_operations | Compose-backed Postgres backup | Medium |
| `scripts/restore-db.sh` | quality_operations | Compose-backed Postgres restore | High |
| `docs/ed25519-keys.md` | docs_dx | Key generation and storage guidance without committed secrets | Medium |
| `reports/*.md` | workflow_design | Agent handoffs and validation reports | Low |
| `implementation_plan.md` | workflow_design | User-gated plan | Low |
| `task.md` | workflow_design | Post-approval checklist | Low |
| `walkthrough.md` | scribe | Closeout and validation record | Low |

## Denied Scope For L1

- `.env`
- Private keys or generated signing material
- Database dumps or backup artifacts
- Stripe/shop integration
- Client SDKs
- Auto-update code
- Version bumps, releases, commits, or pushes without explicit approval

## Dependency Flow

1. Governance and write scope.
2. Environment template and Compose stack.
3. Product registry and `nerdkey apply` CLI.
4. Admin/bootstrap script and license workflow.
5. Backup/restore scripts.
6. README and key documentation.
7. Static validation.
8. Runtime smoke validation.
9. Changelog and walkthrough.

## Validation Gates

- `git status --short --branch`
- `docker compose config`
- Python syntax check for `scripts/nerdkey.py`
- Shell syntax check for backup/restore scripts
- `shellcheck scripts/*.sh` when available
- `docker compose up -d` and `GET /v1/health`
- Scripted product apply, policy/license/machine-seat smoke test: 2 activations pass, third activation rejected
- Secret scan of tracked files and ignored artifacts
