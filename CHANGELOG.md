# Changelog

All notable user-facing changes to NerdKey are tracked here.

## [Unreleased]

### Added

- Bootstrap repo-local governance for the NerdKey Keygen CE setup.
- Add the local Keygen CE Docker Compose stack with Postgres, Redis, Caddy, setup/migration jobs, and `.env.example`.
- Add the `products.yaml` product registry plus idempotent `scripts/nerdkey apply` policy synchronization.
- Add admin CLI flows for health checks, token issuing, public-key output, product registration, license issuing/listing/revocation/validation/checkout, machine activation, and the L1 smoke test.
- Add Ed25519 key-handling documentation and database backup/restore scripts.
- Add validation reports and a setup walkthrough for the L1 operator workflow.
- Mark L1 complete in the README, task list, licensing standard, and roadmap.
