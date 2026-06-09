# Changelog

All notable user-facing changes to NerdKey are tracked here.

## [Unreleased]

### Added

- **Production deployment to `https://keys.nerdsmiths.de`** (release impact: `minor`)
  - `docker-compose.prod.yml`: Keygen CE stack (`web`, `worker`, `postgres`,
    `redis`) with no Caddy; `web` bound to `127.0.0.1:3055` so TLS terminates at
    the host NGINX reverse proxy.
  - `config/nginx/keys.nerdsmiths.de.conf.example`: NGINX vHost template
    (ACME HTTP-01 via `/var/www/html`, Let's Encrypt TLS, proxy to `127.0.0.1:3055`).
  - `scripts/prod-backup.sh`: prod-aware `pg_dump` with `0600` dumps, 14-dump
    retention, and a daily cron entry; preserves the migration dump.
  - `docs/production-rollout.md`: operator runbook for DB migration, secret
    rules, two-phase TLS issuance, validation evidence, backups, and rollback.
  - `.env.example` / `README.md`: production hints and Caddy-vs-NGINX clarification.
  - Live cutover preserved the embedded account `6ff939de-…` and Ed25519 public
    key by migrating the local Keygen database and its encryption secrets.

## [L3] - 2026-06-06

### Added

- **Client SDK — Swift / macOS** (`kit/swift/`)
  - SwiftPM package with `NerdKeyKit` library and `nerdkey-cli` proof executable
  - Dependency: `swift-crypto` (Apple, `>= 3.0.0`) for Ed25519 offline verification
  - Public API: `activate(licenseKey:) async throws`, `validateOnLaunch() async throws`, `deactivate() async throws`
  - Offline Ed25519 signature verification against the embedded account public key; signing input is `key/<payload-base64>` as ASCII bytes (Keygen CE `ED25519_SIGN` format)
  - Online refresh every 5 days (`REFRESH_DAYS`); 7-day grace window (`GRACE_DAYS`) on network error
  - Machine fingerprint: `system_profiler` serial number (macOS), `/etc/machine-id` (Linux), SHA-256
  - State stored in `~/Library/Application Support/nerdsmiths/<appSlug>/license.json`
  - Typed error enum: `NerdKeyError` (notActivated, seatLimitExceeded, expired, revoked, networkErrorWithinGrace, networkErrorGraceExpired, invalidSignature, invalidLicense)
  - Build proven live with Apple Swift 6.2.3; all 7 proof steps passed against local NerdKey CE

- **Client SDK — .NET / Windows + Linux** (`kit/dotnet/`)
  - .NET 8 solution: `NerdKey.Kit` class library and `NerdKey.Example` console proof app
  - Dependency: `BouncyCastle.Cryptography 2.4.0` for Ed25519 offline verification
  - Public API: `ActivateAsync(licenseKey)`, `ValidateOnLaunchAsync()`, `DeactivateAsync()`
  - Same offline verify, refresh, and grace logic as Swift implementation
  - Machine fingerprint: Windows registry `MachineGuid`, Linux `/etc/machine-id`, macOS `system_profiler`, SHA-256
  - State stored in `%APPDATA%\nerdsmiths\<appSlug>\license.json` (Windows)
  - Typed exception hierarchy: `NotActivatedException`, `SeatLimitExceededException`, `LicenseExpiredException`, `LicenseRevokedException`, `NetworkErrorWithinGraceException`, `NetworkErrorGraceExpiredException`, `InvalidSignatureException`, `InvalidLicenseException`
  - Build proven via Docker (`mcr.microsoft.com/dotnet/sdk:8.0`); all 7 proof steps passed against local NerdKey CE

- **Integration Guide** (`kit/INTEGRATION_GUIDE.md`)
  - Covers both platforms: add dependency, embed constants, create SDK object, activate, validate on launch, deactivate
  - Machine fingerprint strategy and license.json path per OS
  - Offline/grace model diagram
  - Re-embedding the public key procedure
  - Development proof commands
  - Complete error taxonomy table (Swift enum cases vs .NET exception types)

- **Embedded constants** (both SDKs)
  - Account ID: `6ff939de-b619-496f-ba99-e59bf64349e4`
  - Ed25519 public key (base64): `NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==`
  - Default base URL placeholder: `https://nerdkey.localhost` — **must be updated to the production Keygen host before shipping any app**

## [L1] - 2026-06-05

### Added

- Bootstrap repo-local governance for the NerdKey Keygen CE setup.
- Add the local Keygen CE Docker Compose stack with Postgres, Redis, Caddy, setup/migration jobs, and `.env.example`.
- Add the `products.yaml` product registry plus idempotent `scripts/nerdkey apply` policy synchronization.
- Add admin CLI flows for health checks, token issuing, public-key output, product registration, license issuing/listing/revocation/validation/checkout, machine activation, and the L1 smoke test.
- Add Ed25519 key-handling documentation and database backup/restore scripts.
- Add validation reports and a setup walkthrough for the L1 operator workflow.
- Mark L1 complete in the README, task list, licensing standard, and roadmap.
