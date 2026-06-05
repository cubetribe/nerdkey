# Nerdsmiths Shop – Launch-Roadmap

```
> █ road to launch :: nerdsmiths shop
```

**Stand:** 2026-06-06 · **Repo:** github.com/cubetribe/Nerdshmiths_LP · **Version:** v1.8.21
**Ziel:** Vollständig getesteter Shop, der digitale ZIP-Pakete (Mac-/Windows-Apps + DevKits) verkauft.

> **Fortschritt 2026-06-06:** ✅ Shop **Phase A** (digitale Auslieferung + offenes Produktmodell)
> gemerged (PR #6, v1.8.21). ✅ Lizenz-Service **L1** (NerdKey / Keygen CE self-hosted) gebaut und
> lokal validiert (Seat-Limit 2 bestätigt). Nächster Schritt: **L2** (Shop ↔ NerdKey verbinden).

Detaillierte Aufträge inkl. Copy-Paste-Prompts für Claude Code: siehe
`Nerdsmiths_Shop_Audit_und_ClaudeCode_Plan.md`. Diese Roadmap ist die Status-Übersicht.

---

## Status-Legende
`✅ erledigt` · `🟢 in Arbeit` · `⬜ offen` · `🔵 optional` · `👤 Aufgabe Dennis`

---

## Fundament (bereits vorhanden) ✅
- ✅ Stripe Checkout (Einzel + Warenkorb, Promo-Codes, Rechnung, Idempotenz)
- ✅ Webhook-Verarbeitung (Signaturprüfung, Dedup, Refunds, Audit-Log)
- ✅ Kundenkonten (gehashte Sessions, DSGVO-Löschung)
- ✅ PostgreSQL-Schema (Migrationen 003/004) + Backup-Script + Access-Control-Rollen
- ✅ Rechtstexte (Datenschutz mit Shop-Klauseln, Shop-/Lizenzbedingungen)
- ✅ Rate-Limiting + Trusted-Origin-Checks
- ✅ SEO-Baseline (Canonical/404/Sitemap live grün)
- ✅ Retro-Terminal-CI durchgängig

---

## Phasen bis Launch

### Phase A — Digitale Auslieferung & offenes Produktmodell ✅
**Status:** ✅ erledigt (PR #6, v1.8.21, 2026-06-06)
- ✅ Produktmodell auf offene Liste generalisiert (`productType: app|devkit`, Plattform, `assets[]`; `storageKey`/`sha256` nur serverseitig)
- ✅ Geschützter Asset-Speicher (`SHOP_ASSET_DIR`, nie statisch ausgeliefert)
- ✅ Migration 005: `shop_download_tokens`
- ✅ Download-Token idempotent bei Webhook-Erfolg (JSON + Postgres), Revoke bei Refund
- ✅ Endpoint `GET /api/shop/licenses/:id/download` (Auth-before-FS, Path-Traversal-Guard, Expiry + Max-Downloads, atomares Zählen)
- ✅ Download-UI in `ShopAccountPage` (Retro-Terminal, Expired/Limit-States)
- ✅ Deploy-Safety: `SHOP_ASSET_DIR` Soft-Warning + 503 wenn unset; `to_regclass`-Guard für unmigrierte Prod-DB
- Neue Env: `SHOP_ASSET_DIR`, `SHOP_DOWNLOAD_TOKEN_TTL_HOURS` (72), `SHOP_DOWNLOAD_MAX_DOWNLOADS` (10)

### Phase B — Lizenzschlüssel (Aktivierung) 🟢
**Status:** zu eigenem Workstream aufgewertet → **Lizenz-Service** (siehe unten)
- ✅ Engine entschieden: **Keygen CE** (self-hosted, kommerziell kostenlos)
- Details & Bauplan: `Nerdsmiths_Licensing_Standard.md`, Abschnitt 8 (Phasen L1–L4)

### Phase C — Transaktionale Kauf-E-Mails ⬜
**Branch:** `feat/purchase-emails` · **Status:** offen
- `sendPurchaseConfirmation()` (Retro-Terminal-HTML, DE/EN) im Webhook-Erfolgspfad
- Idempotent (1 Mail pro Order, Migration 007), Mailfehler dürfen Webhook nicht failen lassen

### Phase D — Automatisierte Tests ⬜
**Branch:** `test/shop-suite` · **Status:** offen
- Vitest/node:test: Auth, Cart, Checkout (Stripe gemockt), Webhook-Idempotenz, Entitlement-Vergabe, Download-Autorisierung
- `npm run test` + README-Doku
> **Begründung:** „Vollständig getestet" verlangt eine echte Test-Suite.

### Phase E — Produkt-Naming, Schema & Assets ⬜
**Branch:** `chore/product-seo-assets` · **Status:** offen
- Kanonische Schreibweise festlegen (Vorschlag Slug `polywavconverter` / Name `PolyWavConverter`), überall durchziehen, Redirects
- Produkt-JSON-LD vervollständigen (image, sku, seller, OS, Lizenz, Preis == Stripe)
- Screenshots komprimieren (Produktseite war ~9,5 MB), LCP verbessern
- SEO-Roadmap Phase 5 abschließen

### Phase F — Go-Live (Production Readiness) ⬜👤
**Status:** offen, überwiegend Dennis
- 👤 `.env.backend` Prod: `SHOP_STORE_DRIVER=postgres`, `SHOP_COOKIE_SECURE=true`, Stripe **Live**-Keys, Webhook-Secret, Price-IDs, HTTPS-URLs, `ALLOWED_ORIGINS` ohne localhost, least-privilege `DB_USER`, `SHOP_ASSET_DIR`
- 👤 Migrationen auf VPS fahren (003, 004 + neue 005–007)
- ⬜ `npm run shop:readiness:production` grün
- 👤 Stripe-Webhook auf `https://nerdsmiths.de/api/shop/webhook` setzen
- 👤 Search Console + Bing verifizieren, Sitemap einreichen (SEO-Phase 3)
- 👤 End-to-End-Testkauf inkl. Download-Test

---

## Produkt-Paketierung (eigene Session, nach Phase A) ⬜
Sobald das offene Produktmodell steht, ist ein neues Produkt reine Konfiguration
(Eintrag + Stripe-Price + Asset + Screenshots). Geplant gemischt: Mac-Apps + DevKits.
Verkaufsreife der einzelnen Repos noch nicht geprüft.

---

## Workstream: Lizenz-Service (produktübergreifend) 🟢
Repo: **github.com/cubetribe/nerdkey** · Engine: **Keygen CE** (self-hosted, kommerziell kostenlos).
Voller Bauplan: `Nerdsmiths_Licensing_Standard.md` §8.
- ✅ **L1** NerdKey / Keygen CE self-hosted (Docker-Stack, `products.yaml` + `nerdkey apply`,
  Admin-CLI, Backup/Restore, Ed25519-Account-Keys). Lokal validiert: Seat-Limit 2 bestätigt
  (3. Aktivierung abgelehnt), Smoke-Test grün.
- ⬜ **L2** Shop ↔ NerdKey verbinden (`Nerdshmiths_LP`): Webhook stellt Keygen-Lizenz aus, Konto zeigt Key — **NÄCHSTER SCHRITT**
- ⬜ **L3** Client-SDK & Aktivierung (`nerdkey-kit`, Swift + .NET/C++)
- ⬜ **L4** Updates (Sparkle / WinSparkle)
- ⬜👤 Plattform-Signing (macOS Developer ID/Notarisierung, Windows Authenticode)

---

## Offene Entscheidungen (Dennis)
1. ✅ **Aktivierung:** ja, per Lizenz-Service (Keygen CE) — entschieden
2. **Windows zum Launch?** Oder erst macOS + DevKits
3. **Asset-Hosting:** VPS vs. Objektspeicher (S3/R2, signierte URLs)
4. **Launch-Umfang:** 1–2 Produkte (schneller erster Umsatz) vs. mehrere
5. **Lizenz-Details:** Seats pro Lizenz (Vorschlag 2), Update-Berechtigung (lebenslang vs. 1 Jahr)
```
> █ Ende.
```
