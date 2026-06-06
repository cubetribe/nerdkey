# NerdKey Overnight Build — 2026-06-06
**Scope:** L3 Client SDK (kit/swift, kit/dotnet, kit/INTEGRATION_GUIDE.md)
**Context:** Built as part of the Nerdsmiths Shop v1.9.0 overnight build (P6)

---

## Summary

L3 delivers two complete client SDK implementations that allow macOS (Swift) and Windows/Linux (.NET) apps to activate, validate, and deactivate Nerdsmiths licenses against the NerdKey CE backend. Both SDKs were built and proven live against the local NerdKey CE stack. All 7 proof steps passed on both platforms.

---

## kit/ Contents

```
kit/
├── INTEGRATION_GUIDE.md        Shared integration guide (both platforms)
├── swift/
│   ├── Package.swift
│   └── Sources/
│       ├── NerdKeyKit/         Core library
│       │   ├── NerdKey.swift   Public API (activate / validateOnLaunch / deactivate)
│       │   ├── NerdKeyConfig.swift
│       │   ├── NerdKeyConstants.swift  Account ID + Ed25519 public key + base URL
│       │   ├── NerdKeyError.swift      Typed error enum
│       │   ├── LicenseState.swift      license.json model
│       │   └── Fingerprint.swift       macOS + Linux machine fingerprint
│       └── nerdkey-cli/        Proof CLI executable
│           └── main.swift
└── dotnet/
    ├── NerdKey.sln
    ├── NerdKey.Kit/            Core library (net8.0)
    │   ├── NerdKeyClient.cs    Public API (ActivateAsync / ValidateOnLaunchAsync / DeactivateAsync)
    │   ├── NerdKeyConfig.cs
    │   ├── NerdKeyConstants.cs Account ID + Ed25519 public key + base URL
    │   ├── Exceptions.cs       Typed exception classes
    │   ├── LicenseState.cs     license.json model
    │   └── Fingerprint.cs      Windows + Linux + macOS machine fingerprint
    └── NerdKey.Example/        Proof CLI app (net8.0)
        └── Program.cs
```

---

## Embedded Constants

| Constant | Value |
|----------|-------|
| Account ID | `6ff939de-b619-496f-ba99-e59bf64349e4` |
| Ed25519 public key (base64) | `NThhMWFlM2Q0OGI5NmQ2NzkzODNiNGQyYzY1YmNhYTFiOGMzMzViMTdkOWUwN2ZmNzk1MTQyODIyNGJiM2ZhNg==` |
| Default base URL | `https://nerdkey.localhost` (change to production host before shipping) |
| REFRESH_DAYS | 5 |
| GRACE_DAYS | 7 |

The public key is non-secret and safe to ship inside a compiled binary. It is the account's Ed25519 verification key, used only to verify license key signatures offline.

---

## SDK API Surface

Both platforms expose the same three operations:

| Operation | Swift | .NET | Notes |
|-----------|-------|------|-------|
| Activate | `activate(licenseKey:) async throws -> String` (machineId) | `ActivateAsync(licenseKey) -> Task<string>` | Offline verify → Keygen register → save license.json |
| Validate on launch | `validateOnLaunch() async throws` | `ValidateOnLaunchAsync() -> Task` | Offline verify → online refresh every 5 days → grace 7 days |
| Deactivate | `deactivate() async throws` | `DeactivateAsync() -> Task` | Remove machine from Keygen → delete license.json |

---

## Offline Verification

Keygen CE's `ED25519_SIGN` policy signs over the ASCII bytes of `key/<payload-base64>`. This was determined empirically by running proof sequences against the live stack and inspecting the key format. Both SDKs implement this exact input construction before calling the Ed25519 verify function.

---

## Build Results

### Swift

Toolchain: Apple Swift 6.2.3 (host macOS)

```
swift build
Build complete!
```

### .NET

Toolchain: `mcr.microsoft.com/dotnet/sdk:8.0` Docker image (no native dotnet on host)

```
dotnet build NerdKey.sln
Build succeeded.
```

---

## Live Proof Results

Both proofs run against `https://nerdkey.localhost` (TLS skip verify, local self-signed cert).

### Swift — 7 steps

1. Issue license via `python3 scripts/nerdkey.py license issue` — PASS
2. `activate()` machine 1 (`e2e-seat-1`) — PASS, machineId `1e2e8542-...`
3. `activate()` machine 2 (`e2e-seat-2`) — PASS, machineId `061afdc6-...`
4. `activate()` machine 3 (`e2e-seat-3`) — PASS, throws `NerdKeyError.seatLimitExceeded`
5. `validateOnLaunch()` offline (machine 1, within grace) — PASS, returns normally
6. Revoke via `python3 scripts/nerdkey.py license revoke <id>` — PASS, Keygen 204
7. `validateOnLaunch()` after forced online check (state file patched to 8 days ago) — PASS, throws `NerdKeyError.revoked`

### .NET — 7 steps

Same sequence, same results, run inside Docker container with `--add-host=nerdkey.localhost:host-gateway`.

---

## INTEGRATION_GUIDE.md

The guide at `kit/INTEGRATION_GUIDE.md` is the primary developer-facing document. It covers:

- Both platforms end-to-end (add dependency, embed constants, create SDK, activate, validate, deactivate)
- Machine fingerprint algorithm per OS
- license.json file location per OS
- Offline/grace model diagram
- Re-embedding the public key (if the Keygen account changes)
- Proof commands used during development
- Complete error taxonomy (Swift enum cases vs .NET exception types)

---

## Open Items

| Item | Status | Notes |
|------|--------|-------|
| Linux Swift fingerprint | Code-complete, not run | Requires Linux runner (CI or container) |
| Windows .NET native fingerprint | Code-complete, not run | Requires Windows runner |
| .NET native toolchain on build host | Not installed | Docker used; add to dev toolchain for local iteration |
| SDK package publication | Not done | Source-copy model for now; SwiftPM registry + NuGet publication is a future task |
| CI integration | Not done | Suggested: Linux GitHub Actions runner for Swift; Windows runner for .NET |
| Production base URL | Placeholder set | `NerdKeyConstants.defaultBaseURL` must be updated to the production NerdKey host before shipping any app |

---

## Relationship to Shop v1.9.0

The Swift `nerdkey-cli` was used directly in the shop E2E test (P4 Gate 4) to prove the activation and seat-limit behavior against the license issued by the shop webhook. The SDK and shop backend are otherwise independent — the SDK communicates with Keygen CE directly; it does not call any shop API.

---

## L-Level Status

| Level | Description | Status |
|-------|-------------|--------|
| L1 | NerdKey CE stack + admin CLI | Complete (prior work) |
| L2 | Shop ↔ NerdKey webhook integration | Complete (v1.9.0) |
| L3 | Client SDK (Swift + .NET) | Complete — proven, open items on CI only |
| L4 | Auto-update (Sparkle / WinSparkle) | Not started |
