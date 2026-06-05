# Intake Brief

## Request

Set up `cubetribe/nerdkey` as the Nerdsmiths self-hosted license and activation service for Phase L1.

## Binding Inputs

- User prompt for Phase L1.
- `docs/BUILD_BRIEF.md`.
- `docs/Nerdsmiths_Licensing_Standard.md`.
- `docs/Nerdsmiths_ROADMAP.md`.
- Official Keygen self-hosting documentation: https://keygen.sh/docs/self-hosting/
- Keygen API documentation for policies, licenses, machines, tokens, and signed/offline licensing.

The local docs make ease of use a hard acceptance point: adding a product must be one `products.yaml` entry plus `nerdkey apply`.

## Repository State

- Workspace root: `/Volumes/2TB_CodingProjekte/Coding_Projekte/NerdKey`.
- Git was not initialized at intake; it is now initialized on branch `main`.
- Greenfield governance was missing at intake.
- Existing project context: `docs/BUILD_BRIEF.md`.
- Additional project context added by the user: `docs/Nerdsmiths_Licensing_Standard.md`, `docs/Nerdsmiths_ROADMAP.md`, `docs/README.md`.
- Existing local noise: `.DS_Store` files; ignored via `.gitignore`.

## Completed Preflight

- Added minimal repo-local governance in `AGENTS.md`.
- Added `.gitignore` with `.env`, dumps, keys, generated licenses, and local runtime data ignored.
- Added initial `README.md` and `CHANGELOG.md`.
- Confirmed local Docker, Docker Compose, OpenSSL, `jq`, and `curl` are installed.

## Keygen Findings

- Keygen CE is configured with `KEYGEN_EDITION=CE`.
- Singleplayer mode requires `KEYGEN_ACCOUNT_ID`.
- Keygen requires Postgres, Redis, Rails secret/encryption keys, and `KEYGEN_HOST`.
- Health check endpoint is `/v1/health`.
- Self-hosted Keygen has no admin UI; management is via API or Rails console.
- `KEYGEN_HOST` must be a domain name, not an IP address.
- For more than one machine seat, Keygen policy should use strict floating machine leasing with `maxMachines=2`; this implements the requested seat model even though it is not a one-machine node-locked policy.
- Ed25519 signing should use Keygen's signed license capabilities; no custom crypto should be invented.

## Risks

- The project docs request a node-locked/floating seat model; Keygen requires floating policies for more than one machine seat.
- Local TLS/domain behavior must be validated because Keygen expects a host domain.
- Admin-token bootstrap must avoid leaking the only visible copy of generated tokens.
- Backup/restore must be documented as destructive for restore operations.

## Recommendation

Proceed with bounded implementation after user approval. Use Docker Compose with Keygen web, worker, Postgres, Redis, and a local TLS proxy. Pin the Keygen Docker image to the current LTS minor stream. Keep the CLI thin, stdlib-first, idempotent where possible, driven by `.env`, and centered on `products.yaml` plus `nerdkey apply`.
