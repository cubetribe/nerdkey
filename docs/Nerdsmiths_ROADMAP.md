# Nerdsmiths Shop – Launch-Roadmap

```
> █ road to launch :: nerdsmiths shop
```

**Stand:** 2026-06-05 · **Repo:** github.com/cubetribe/Nerdshmiths_LP · **Version:** v1.8.20
**Ziel:** Vollständig getesteter Shop, der digitale ZIP-Pakete (Mac-/Windows-Apps + DevKits) verkauft.

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

### Phase A — Digitale Auslieferung & offenes Produktmodell 🟢
**Branch:** `feat/shop-fulfillment` · **Owner:** Claude Code · **Status:** in Arbeit
- Produktmodell von Single-Product-Literal auf offene Liste generalisieren (`productType: app|devkit`, Plattform, mehrere Assets)
- Geschützter Asset-Speicher (`SHOP_ASSET_DIR`, außerhalb Web-Root)
- Migration 005: `shop_download_tokens`
- Download-Token bei Webhook-Erfolg erzeugen
- Endpoint `GET /api/shop/licenses/:id/download` mit Entitlement- + Token-Prüfung
- Download-UI in `ShopAccountPage` (Retro-Terminal-Stil)
> **Begründung Priorität 1:** Ohne diese Phase bekommt ein zahlender Kunde nichts Herunterladbares.

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
Eigener, wiederverwendbarer Workstream (parallel zur Shop-Roadmap). Engine: **Keygen CE**
(self-hosted, kommerziell kostenlos). Voller Bauplan: `Nerdsmiths_Licensing_Standard.md` §8.
- ⬜ **L1** Keygen CE self-hosted aufsetzen (`nerdsmiths-licensing`)
- ⬜ **L2** Shop ↔ Lizenz-Service verbinden (`Nerdshmiths_LP`)
- ⬜ **L3** Client-SDK & Aktivierung (`nerdsmiths-license-kit`, Swift + .NET/C++)
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
