<div align="center">

# NerdKey

```
> █ nerdkey :: nerdsmiths licensing & activation service
> Build it once. License everything.
```

**Self-hosted license & activation service for all Nerdsmiths software — macOS and Windows.**

![Status](https://img.shields.io/badge/status-L1%20in%20development-orange?style=for-the-badge)
![Engine](https://img.shields.io/badge/engine-Keygen%20CE-00ff41?style=for-the-badge)
![Self-hosted](https://img.shields.io/badge/self--hosted-yes-blue?style=for-the-badge)
![License](https://img.shields.io/badge/license-Proprietary-lightgrey?style=for-the-badge)

</div>

---

## What is NerdKey?

NerdKey is the central, **product-agnostic** licensing and activation service behind every
Nerdsmiths product. One system issues, activates, and revokes licenses for **all** our macOS and
Windows apps — fully self-hosted, with no third-party SaaS lock-in.

It is built on **[Keygen CE](https://keygen.sh)** (self-hosted, commercially free) and adds a thin,
config-driven admin layer on top so that day-to-day licensing is trivial.

> **One repo. Every product. Self-hosted. No lock-in.**

---

## ⭐ Design Goal: add a license in under 2 minutes

The single most important requirement: licensing must be **effortless** in daily use.

- **Add a new product / license = one config entry + one command.**
  A new block in `products.yaml` → `nerdkey apply`.
- **One central, well-commented config file** (`products.yaml`) as the single source of truth for
  every product, seat count, and license model.
- **A clear admin CLI**: `nerdkey product add`, `nerdkey apply`,
  `nerdkey license issue | revoke | list`.
- **Idempotent & repeatable** — re-running `apply` changes nothing unexpectedly.
- **Documented** — copy-paste examples for the five most common tasks.

The benchmark: a new product is live in **under two minutes, without opening the Keygen API docs.**

---

## Architecture principles

- **Offline-first.** Each license is an **Ed25519-signed file**; the app verifies the signature
  locally on every launch, with a periodic online re-check (3–7 days) and a grace period.
- **Seat model.** Activation binds a license to a machine fingerprint; the server enforces the seat
  limit (default **2** devices). Deactivating frees a seat.
- **Signing keys never touch the web/download server** — they live in operator-managed secrets,
  never in Git.
- **Refund → revoke.** Wired to the shop's Stripe `charge.refunded` flow (later phase).
- **Platform code-signing** (macOS Developer ID/notarization, Windows Authenticode) is handled at
  the app level — out of scope for NerdKey.

---

## How it will work (target usage)

> Target developer experience. Phase L1 is being implemented now — see **Status** below.

```bash
# 1. Bring up the self-hosted Keygen CE stack
docker compose up -d

# 2. Define a product once, in products.yaml
#    - slug: polywavconverter
#      seats: 2
#      model: perpetual

# 3. Apply the config (idempotent)
nerdkey apply

# 4. Issue, list, and revoke licenses
nerdkey license issue  --product polywavconverter --email kunde@example.com
nerdkey license list   --product polywavconverter
nerdkey license revoke --key XXXX-XXXX-XXXX-XXXX
```

---

## Planned repository layout

```
nerdkey/
├── docker-compose.yml     # local Keygen CE stack (API + Postgres + Redis)
├── config/                # reverse-proxy / runtime config (safe to commit)
├── products.yaml          # single source of truth for all products & seats
├── policies/              # policy-as-code templates per product
├── scripts/               # thin operator / admin scripts (the nerdkey CLI)
├── docs/                  # setup, operations, backup/restore, key management
└── reports/               # workflow handoff & validation reports
```

---

## Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| **L1** | Self-host Keygen CE, `products.yaml` + `apply`, admin CLI, backup/restore | 🟢 in development |
| **L2** | Shop integration (`Nerdshmiths_LP`): Stripe webhook issues licenses | ⬜ planned |
| **L3** | Client SDK (`nerdkey-kit`): Swift + .NET/C++, activation & launch check | ⬜ planned |
| **L4** | Auto-updates: Sparkle (macOS) + WinSparkle (Windows), signed appcasts | ⬜ planned |

Full plan: [`docs/Nerdsmiths_Licensing_Standard.md`](docs/Nerdsmiths_Licensing_Standard.md) · §8.

---

## Status

NerdKey is in **Phase L1** (self-hosting Keygen CE + the config-driven admin layer). The repository
is governance-bootstrapped; the approved build plan lives in
[`implementation_plan.md`](implementation_plan.md) and [`docs/BUILD_BRIEF.md`](docs/BUILD_BRIEF.md).
Application code is being added under the GodMode workflow.

**Out of scope for L1:** shop/Stripe integration, client SDKs, auto-updates.

---

## Security

- Secrets live in `.env` (operator-managed) — **never committed**. `.env.example` stays complete but value-free.
- **Ed25519 private/signing keys and generated license files are never stored in Git.**
- Production uses least-privilege database roles; the signing key is kept off the public-facing server.

---

## Engine licensing

NerdKey self-hosts **Keygen CE**, which is *free to self-host for personal and commercial projects*
under the Fair Core License. The only restriction (re-selling Keygen itself as a competing licensing
SaaS) does not apply to our use. Keygen's source becomes Apache-2.0 two years after release.

---

## Documentation

| Doc | Purpose |
|-----|---------|
| [`docs/BUILD_BRIEF.md`](docs/BUILD_BRIEF.md) | Start here — what NerdKey is, principles, L1 scope, build prompt |
| [`docs/Nerdsmiths_Licensing_Standard.md`](docs/Nerdsmiths_Licensing_Standard.md) | Company-wide licensing standard & full build plan (L1–L4) |
| [`docs/Nerdsmiths_ROADMAP.md`](docs/Nerdsmiths_ROADMAP.md) | Overall roadmap & status context |
| [`AGENTS.md`](AGENTS.md) | Agent/contributor guide, boundaries, validation |

---

## License

Copyright © 2026 Nerdsmiths. All rights reserved. Proprietary — not for redistribution.

📧 **hey@nerdsmiths.de** · 🌐 [nerdsmiths.de](https://nerdsmiths.de)

<div align="center">

```
> █ Build it once. License everything.
```

</div>
