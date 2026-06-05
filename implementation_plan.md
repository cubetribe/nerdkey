# Implementation Plan

## Goal

Build NerdKey Phase L1: a reproducible self-hosted Keygen CE licensing and activation service for Nerdsmiths.

## Decisions

- Use Keygen CE as the sole licensing engine.
- Use Docker Compose for Keygen API, worker, Postgres, Redis, and local reverse proxy.
- Use `nerdkey.localhost` instead of an IP because Keygen requires `KEYGEN_HOST` to be a domain name.
- Keep secrets exclusively in `.env`; commit only `.env.example`.
- Implement the requested default 2-seat model as a strict floating machine policy with `maxMachines=2`, because Keygen's non-floating node-locked policy is limited to one machine.
- Use Keygen's Ed25519 signed license support and document key handling; do not invent custom license crypto.
- Treat `products.yaml` as the single source of truth. The default workflow is one config entry plus `nerdkey apply`.

## Build Steps

1. Add `.env.example` with all required Keygen, database, Redis, and local admin variables.
2. Add `docker-compose.yml` with Keygen CE web/worker, Postgres, Redis, and Caddy proxy.
3. Add `compose/Caddyfile` for local TLS routing to Keygen.
4. Add `products.yaml` with a demo product and a small built-in parser for the required YAML subset.
5. Add `policies/products/nerdsmiths-demo.json` as the generated/reference policy-as-code fixture.
6. Add `scripts/nerdkey.py` for health, admin token bootstrap guidance, `product add`, `apply`, license issue/list/revoke/validate, machine activate/deactivate, and smoke test.
7. Add `scripts/backup-db.sh` and `scripts/restore-db.sh` for Keygen Postgres backup/restore.
8. Add `docs/ed25519-keys.md` documenting Ed25519 generation/storage and Keygen account public key retrieval without storing private keys in Git.
9. Expand `README.md` into a no-questions setup guide with the five common tasks.
10. Add `task.md`, validation reports, `walkthrough.md`, and update `CHANGELOG.md`.

## Validation

1. Run `docker compose config`.
2. Compile-check Python and shell scripts.
3. Run `shellcheck` if installed.
4. Start the stack with `docker compose up -d`.
5. Check Keygen health via the local URL.
6. Run the smoke path:
   - apply test product/policy
   - create test license
   - list and revoke the test license
   - validate license key
   - activate machine fingerprints `seat-1` and `seat-2`
   - confirm `seat-3` is rejected
7. Confirm no secrets, key material, dumps, or generated licenses are tracked.

## Assumptions

- Docker is available locally.
- Python 3 is available locally.
- `.env` may be generated locally from `.env.example`, but it must never be committed.
- `docs/BUILD_BRIEF.md` and `docs/Nerdsmiths_Licensing_Standard.md` control Phase L1.

## Approval Gate

Implementation stops here until the user approves this plan.
