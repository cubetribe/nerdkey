# Runtime Validation

Scope: local self-hosted Keygen CE stack and NerdKey admin workflow.

## Result

PASS

## Stack

`docker compose ps` showed:

| Service | Result |
|---------|--------|
| `postgres` | Up, healthy |
| `redis` | Up, healthy |
| `web` | Up on host port `3000` |
| `worker` | Up |
| `caddy` | Up on host ports `80` and `443` |

## Checks

| Check | Result | Notes |
|-------|--------|-------|
| `docker compose --profile setup run --rm setup` | PASS | Created local account, admin user, database schema, and account signing keys. |
| `docker compose up -d` | PASS | Stack starts locally. |
| `scripts/nerdkey health` | PASS | Keygen health endpoint is reachable; empty health body is reported as `null`. |
| `scripts/nerdkey token issue --save` | PASS | Saved admin token into ignored `.env`. |
| `scripts/nerdkey apply` | PASS | Demo product and policy are created/updated. |
| repeated `scripts/nerdkey apply` | PASS | Product and policy sync is idempotent. |
| `scripts/nerdkey account public-key --json` | PASS | Prints account public keys, including Ed25519. |
| `scripts/nerdkey smoke` | PASS | Issues a smoke license, activates 2 machines, validates the license, rejects the 3rd machine, then revokes the smoke license. |
| `scripts/backup-db.sh backups/nerdkey-test.dump` | PASS | Wrote a local PostgreSQL backup into ignored `backups/`. |
| `scripts/restore-db.sh` | GATED | Present and syntax-checked; runtime restore requires `NERDKEY_RESTORE_CONFIRM=replace-local-db` because it replaces the local DB. |

## Seat-Limit Evidence

The smoke test activated two machine fingerprints successfully. The third activation was rejected by Keygen with:

```text
machine count has exceeded maximum allowed for license (2)
```

This verifies the requested default 2-seat model.

## Runtime Findings

- For 2 seats, Keygen requires a floating policy with `maxMachines=2`; NerdKey uses strict floating machine leasing.
- Machine activation with a license key requires `authenticationStrategy=LICENSE`.
- The local Caddy certificate is internal; NerdKey defaults `NERDKEY_TLS_VERIFY=false` for local workflows.
- Optional Keygen disable flags such as `NO_SENTRY=1` are not set because they conflict with the pinned Docker image's frozen bundle.
