# Nerdsmiths Licensing Standard (2026)

```
> █ nerdsmiths :: how we license & activate our software
> One standard. Every product. Self-hosted. No third-party lock-in.
```

**Zweck:** Diese Entscheidung lösen wir **einmal** und nutzen sie für **jedes** zukünftige
Produkt (Mac- und Windows-Apps, DevKits). Dieses Dokument ist der verbindliche Architektur-
und Best-Practice-Standard.

**Stand:** 2026-06-05 · **Status:** ✅ Engine entschieden — **Keygen CE** (self-hosted, kommerziell kostenlos)

---

## 1. Anforderungen (von Dennis)

- Mac- **und** Windows-Programme verkaufen.
- Installation auf so vielen Rechnern, wie Lizenzen freigeschaltet sind (Seat-Modell).
- Updates ausliefern und verifizieren.
- Lizenzabfrage beim App-Start (selbstverständlich).
- **Selbst gehostet, einmal sauber gelöst, skalierbar** — kein Drittanbieter-Lock-in,
  keine gekauften Lizenzpakete.

---

## 2. Grundprinzip: Trennung der Zuständigkeiten

Drei Bausteine, klar getrennt:

```
   ┌──────────────┐   Stripe-Webhook    ┌────────────────────┐
   │   SHOP        │ ──(Kauf bezahlt)──▶ │  LICENSING-SERVICE  │
   │ Nerdshmiths_LP│                     │  (eigenes Repo)     │
   │  = Verkauf    │ ◀─(Lizenz/Key)───── │  = Wahrheit über     │
   └──────────────┘                     │    Lizenzen & Seats │
          ▲                             └────────────────────┘
          │ zeigt Key + Download                  ▲
          │                                        │ aktivieren / prüfen
   ┌──────┴───────┐                                │
   │   KUNDE      │        ┌───────────────────────┴───┐
   └──────────────┘        │   APP (Mac / Windows)      │
                           │   = dünner Client,         │
                           │     prüft Lizenz lokal      │
                           └────────────────────────────┘
```

- **Shop** (`Nerdshmiths_LP`): verkauft, kassiert (Stripe), zeigt Konto/Download/Key. Kennt
  keine Lizenz-Logik.
- **Licensing-Service** (neu, **eigenes Repo**): einzige Wahrheit über Lizenzen, Aktivierungen,
  Seats, Widerruf. Stellt nach Zahlung eine Lizenz aus, aktiviert Maschinen, prüft Limits.
- **App**: dünner Client. Validiert eine signierte Lizenzdatei lokal bei jedem Start; meldet
  sich periodisch beim Service zur Aktivierung/Nachprüfung.

> **Warum getrennt?** Du baust die Lizenz-Logik **einmal** und bindest sie in jedes Produkt ein.
> Der Shop bleibt schlank, jede App bleibt dünn. Genau das skaliert.

---

## 3. Best Practice 2026 — die 7 Bausteine

### 3.1 Offline-first mit Ed25519-signierten Lizenzdateien
Die App erhält bei der Aktivierung eine **signierte Lizenzdatei** (Inhalt: Produkt, Kunde,
Seats, Ablauf/Update-Berechtigung, Maschinen-Fingerprint). Die App trägt den **Public Key
eingebettet** und prüft die Signatur bei **jedem Start lokal** — ohne Netz.
- **Ed25519** ist 2026 der Standard: kompakt, schnell, FIPS-186-5-zugelassen, kein RSA nötig.
- Vorteil: funktioniert offline, übersteht Server-Ausfälle, ist fälschungssicher.
- Ergänzung: **periodische Online-Nachprüfung** (z.B. alle 3–7 Tage) für Widerruf/Seat-Kontrolle.

### 3.2 Maschinen-Aktivierung & Seat-Modell
- Lizenzschlüssel → **Aktivierung** bindet an einen **Maschinen-Fingerprint**
  (Kombination aus stabilen Hardware-IDs: CPU, Disk-Serial, MAC).
- Server zählt Aktivierungen und erzwingt das Limit (z.B. „2 Geräte pro Lizenz").
- **Deaktivieren** gibt einen Seat frei (für Rechnerwechsel) — wichtig für Support-Last.

### 3.3 Lizenzabfrage beim Start
- Beim Start: lokale Signaturprüfung der Lizenzdatei (immer) + Cache-Check des letzten
  Online-Status. Online-Re-Check nur im Intervall, nicht bei jedem Start (kein Offline-Bruch).
- Kulanter Umgang mit „Server nicht erreichbar": Grace-Period statt sofortiger Sperre.

### 3.4 Signing-Keys vom Auslieferungs-Server trennen
- Der **private Signaturschlüssel** liegt in einem Secret-Manager/HSM, **niemals** auf dem
  VPS, der Downloads/Updates ausliefert.
- Grund: Ein kompromittierter Web-/Download-Server darf weder Lizenzen noch Updates fälschen können.

### 3.5 Updates: Sparkle (macOS) + WinSparkle (Windows)
- Beide teilen das **Appcast-Format** und signieren Update-Artefakte mit **EdDSA/Ed25519**.
- Ein gemeinsames Update-Konzept für beide Plattformen.
- Updates können an gültige Lizenz/Entitlement gekoppelt werden (signierte Appcast-URL je Kunde).

### 3.6 Plattform-Signing (getrennt von der Lizenz-Signatur, aber Pflicht)
- **macOS:** Developer-ID-Signatur + **Notarisierung** + Hardened Runtime. Sonst Gatekeeper-Block.
- **Windows:** **Authenticode** (idealerweise EV-Zertifikat oder Azure Trusted Signing), sonst
  SmartScreen-Warnung beim Download/Start.
- Das ist die Voraussetzung, dass die App auf fremden Rechnern überhaupt sauber startet.

### 3.7 Widerruf & Refunds
- Server führt eine **Revocation-Liste**; die periodische Online-Nachprüfung der App respektiert sie.
- Anschluss an den bestehenden Stripe-`charge.refunded`-Webhook → Lizenz auf `revoked`.

---

## 4. Build vs. Adopt — die Engine-Wahl

Du musst die Kryptographie **nicht** selbst erfinden. Zwei saubere, vollständig selbst-gehostete Wege:

### Option A — Keygen CE (empfohlen für Tempo + Zukunftssicherheit)
- Open-/Fair-Source Lizenz-API, **kommerziell kostenlos selbst hostbar** (Fair Core License).
- Out-of-the-box: Lizenz-Erstellung, Maschinen-Aktivierung/Fingerprinting, Seats, Entitlements,
  **Ed25519-Lizenzdateien**, Offline-/Air-Gapped-Aktivierung, Distribution/Update-Channels.
- **Fertige SDKs** u.a. für Swift (macOS), C#/.NET & C/C++ (Windows), Go, Rust, JS.
- Vorteil: kein Neuerfinden von Edge-Cases (Uhr-Manipulation, Fingerprint-Drift, Revocation).
- Aufwand: Postgres + API hosten, an Stripe-Webhook anbinden, SDK in die Apps einbauen.

### Option B — Eigenbau (minimaler Ed25519-Dienst)
- Maximale Kontrolle, du besitzt 100 %. ~Ein paar hundert Zeilen Server + Client je Plattform.
- Du baust selbst: Schlüssel-Erzeugung, Aktivierungs-Endpoint, Fingerprint, Seat-Zählung,
  Revocation, Lizenzdatei-Format.
- Vorteil: kein Fremd-Code, exakt dein Modell. Nachteil: alle Sonderfälle/Wartung bei dir.

| Kriterium | Keygen CE | Eigenbau |
|-----------|-----------|----------|
| Zeit bis robust | Tage | Wochen |
| Edge-Cases gelöst | ✅ erprobt | selbst tragen |
| SDKs Mac/Windows | ✅ vorhanden | selbst schreiben |
| Volle Code-Hoheit | teilweise (Fair Source) | ✅ vollständig |
| Kosten | 0 € (self-host) | 0 € (nur Zeit) |
| Lock-in | keiner (self-host) | keiner |

> **Empfehlung:** **Eigenes Repo in jedem Fall.** Als Engine **Keygen CE**, außer du willst
> bewusst die volle Code-Hoheit — dann der schlanke Ed25519-Eigenbau. Beide sind self-hosted
> und drittanbieter-unabhängig.
>
> ✅ **ENTSCHIEDEN (2026-06-05): Keygen CE.** Lizenzfrage geklärt — Keygen CE ist laut Hersteller
> „free to self-host for personal **and commercial** projects". Einzige Auflagen: Non-Compete
> (Keygen nicht selbst als konkurrierenden Lizenz-SaaS weiterverkaufen — irrelevant für uns),
> keine fertige Self-Host-Admin-UI in CE (Verwaltung per API / kleines Eigen-Admin), nur
> Community-Support. Code wird nach 2 Jahren Apache-2.0.

---

## 5. Empfohlene Repo-Struktur

```
nerdsmiths-licensing/        # eigener Service (Keygen CE ODER Eigenbau)
  ├─ Lizenz-API + DB (Postgres)
  ├─ Stripe-Webhook-Anbindung (Lizenz nach Kauf ausstellen)
  └─ Admin (Lizenzen, Seats, Revocation)

nerdsmiths-license-kit/      # wiederverwendbares Client-SDK
  ├─ swift/                  # für macOS-Apps
  └─ dotnet/ (oder cpp/)     # für Windows-Apps
```

Jede neue App bindet `nerdsmiths-license-kit` ein → drei Zeilen zum Aktivieren/Prüfen.
Das ist das **wiederverwendbare Asset**, das die Frage „wie geht das mit dem Lizenzschlüssel"
in jedem künftigen Projekt mit einem Import beantwortet.

---

## 6. Einbindung in den bestehenden Shop

Passt sauber an den vorhandenen Stand (`Nerdshmiths_LP`):
1. Stripe-Webhook `checkout.session.completed` (existiert) → ruft Licensing-Service:
   „stelle Lizenz für dieses Entitlement aus".
2. Shop-Konto (`ShopAccountPage`) zeigt Lizenzschlüssel + Download (Phase A der Shop-Roadmap).
3. App aktiviert mit dem Schlüssel gegen den Licensing-Service, lädt signierte Lizenzdatei.
4. Refund-Webhook (`charge.refunded`) → Lizenz `revoked`.

> Das ergänzt **Phase B** der bestehenden `ROADMAP.md` — diese wird damit von „optional" zu
> einem eigenen, produktübergreifenden Baustein aufgewertet.

---

## 7. Entscheidungen

- ✅ **Engine: Keygen CE** (entschieden 2026-06-05).
- ✅ **Eigenes Repo** für Service + SDK.

Sekundär (vor/bei Phase L1 festlegen):
- Seat-Default pro Lizenz (Vorschlag: 2 Geräte).
- Update-Berechtigung: lebenslang vs. 1 Jahr Updates inklusive.
- Windows-Signing: EV-Zertifikat vs. Azure Trusted Signing.

---

## 8. Claude-Code-Bauplan (Lizenz-Service)

> Eigener Workstream, parallel zur Shop-Roadmap. Phasen L1–L4. Jede Phase = eine Claude-Code-Sitzung.

> ⭐ **Oberste Produkt-Priorität (Easy to use):** nerdkey muss im Alltag trivial sein.
> **Neues Produkt/neue Lizenz hinzufügen = EIN Eintrag in einer zentralen Config (`products.yaml`)
> + EIN Befehl (`nerdkey apply`).** Zentrale Config als Single Source of Truth, ein Admin-CLI mit
> klaren Befehlen (`product add`, `apply`, `license issue|revoke|list`), Backup/Restore je ein
> Befehl, README mit Copy-Paste-Beispielen. Messlatte: neues Produkt in < 2 Minuten, ohne API-Doku.

### Phase L1 — Keygen CE self-hosted aufsetzen
**Repo:** `nerdsmiths-licensing`
```
Ziel: Keygen CE als self-hosted Lizenz-Server produktionsreif aufsetzen.
1. Neues Repo nerdsmiths-licensing. Keygen CE via Docker Compose (API + Postgres + Redis)
   nach offizieller Self-Hosting-Doku (keygen.sh/docs/self-hosting). LTS-Image pinnen.
2. Ed25519-Signing-Keypair erzeugen; PRIVATE Key in Secret-Manager/Server-Env, NICHT im Repo,
   NICHT auf dem Download-Server. Public Key dokumentieren (kommt später in die Apps).
3. Pro Produkt eine Keygen-Policy anlegen (perpetual license, machine/activation limit = Seats,
   Fingerprint-Strategy, floating/node-locked). Konfiguration als Code/Script ablegen.
4. Admin-Zugriff über API-Token regeln (CE hat keine UI); minimal-Skripte oder kleines
   Admin-Panel für Lizenz-Anlage/Revoke. Backup für die Keygen-DB einrichten.
5. README mit Setup, Env-Vars, Policy-Schema, Backup/Restore.
Constraints: Keine Secrets committen. Reproduzierbares Compose-Setup.
```

### Phase L2 — Shop ↔ Lizenz-Service verbinden
**Repo:** `Nerdshmiths_LP` (Branch `feat/licensing-integration`)
```
Ziel: Nach Kauf automatisch eine Keygen-Lizenz ausstellen und im Konto zeigen.
1. Im Stripe-Webhook-Erfolgspfad (completeOrderFromCheckoutSession): pro Entitlement die
   passende Keygen-Policy (Mapping productSlug -> policyId) aufrufen und Lizenz erstellen.
2. Keygen license id + key auf dem Entitlement speichern (Migration). Idempotent (1 Lizenz pro
   order_item, kein Doppel bei Webhook-Retry).
3. ShopAccountPage: Lizenzschlüssel anzeigen (Copy-Button) + Download (verknüpft mit Shop-Phase A),
   Retro-Terminal-Stil.
4. charge.refunded -> Keygen-Lizenz suspend/revoke.
Constraints: Keygen-Admin-Token nur aus Env. lint/typecheck/build grün; CHANGELOG + Version.
```

### Phase L3 — Client-SDK & Aktivierung
**Repo:** `nerdsmiths-license-kit`
```
Ziel: Wiederverwendbares Aktivierungs-/Prüf-SDK je Plattform, plus Pilot-Integration.
1. swift/ : Wrapper um das Keygen Swift SDK — activate(key) (Maschinen-Fingerprint, validate),
   signierte Lizenzdatei lokal speichern, validateOnLaunch() = lokale Ed25519-Prüfung bei jedem
   Start + periodischer Online-Re-Check (Intervall 3–7 Tage) mit Grace-Period bei Offline.
2. dotnet/ (oder cpp/) : dieselbe API für Windows mit dem .NET/C-SDK von Keygen.
3. Public Key aus Phase L1 eingebettet. Seat-Überschreitung/Revoke sauber als UI-Status.
4. Pilot-Integration in eine App (z.B. PolyWavConverter): Aktivierungs-Dialog + Start-Check.
Constraints: Keine privaten Schlüssel im Client. Beispiel-App + Doku „so bindest du es ein".
```

### Phase L4 — Updates (Sparkle / WinSparkle)
```
Ziel: Signierte Auto-Updates für Mac und Windows.
1. macOS: Sparkle integrieren, Appcast + EdDSA-signierte Update-Artefakte (Signing-Key getrennt
   vom Server).
2. Windows: WinSparkle integrieren, gleiches Appcast-Format, Ed25519-Signatur.
3. Optional: Appcast je Entitlement/Lizenz absichern.
```

### Plattform-Signing (👤 Dennis, Voraussetzung fürs Ausliefern)
- macOS: Apple Developer ID + Notarisierung + Hardened Runtime.
- Windows: Authenticode (EV-Zertifikat oder Azure Trusted Signing).

---

## 9. Quellen (Recherche 2026-06-05)

- Keygen — Self-Hosting & Software Licensing API: https://keygen.sh/docs/self-hosting/ · https://github.com/keygen-sh/keygen-api
- Keygen — Offline-/Air-Gapped-Lizenzierung (Ed25519): https://keygen.sh/docs/choosing-a-licensing-model/offline-licenses/ · https://github.com/keygen-sh/air-gapped-activation-example
- Ed25519 Best Practice / Machine Binding: https://licenseseat.com/software-activation
- Sparkle (macOS Updates, EdDSA): https://sparkle-project.org/documentation/
- WinSparkle (Windows Updates, Ed25519): https://github.com/vslavik/winsparkle
- Code Signing & Notarisierung mit Sparkle (2025): https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears

```
> █ Ende. Build it once. License everything.
```
