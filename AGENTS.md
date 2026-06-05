# NerdKey Agent Guide

## Project Mission

NerdKey is the Nerdsmiths self-hosted licensing and activation service. Phase L1 uses Keygen CE as the licensing engine; do not implement custom licensing crypto.

`docs/BUILD_BRIEF.md` is binding project context for Phase L1. If `Nerdsmiths_Licensing_Standard.md` is added later, treat it as binding architecture context too.

## Boundaries

- Work only in this repository unless the user explicitly asks for another clone or worktree.
- Keep changes small, buildable, and scoped to the current phase.
- Do not commit, push, force-push, or rewrite history without explicit user approval.
- Do not add Stripe, shop integration, client SDKs, or auto-update flows during L1.

## Secret Handling

- Secrets belong in `.env` or operator-managed paths referenced by `.env`.
- Never commit `.env`, database dumps, signing keys, private keys, tokens, or generated license files.
- Keep `.env.example` complete but value-free.
- Keygen signing material and Ed25519 private keys must never be stored in Git.

## Source Layout

- `docker-compose.yml`: local Keygen CE stack.
- `config/`: reverse proxy and runtime config that is safe to commit.
- `policies/`: policy-as-code JSON templates per product.
- `scripts/`: thin operator/admin scripts.
- `docs/`: setup, operations, backup/restore, and key-management notes.
- `reports/`: agent handoff and validation reports.

## Validation

- Run checks that match the touched scope.
- For L1 infrastructure changes, prefer:
  - `docker compose config`
  - `shellcheck scripts/*.sh` when shellcheck is available
  - `docker compose up` followed by `/v1/health`
  - the repository smoke script for policy, license, validation, and seat-limit behavior

## Release Law

- This repo starts with `CHANGELOG.md` using a `[Unreleased]` section.
- Classify changes as `major`, `minor`, `patch`, or `none` in release summaries.
- Do not create version bumps or releases unless the user asks.
