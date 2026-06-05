# nerdkey — Build-Brief (Referenz für Codex GodMode)

```
> █ nerdkey :: nerdsmiths licensing & activation service
> Build it once. License everything.
```

**Repo:** github.com/cubetribe/nerdkey (leer / greenfield) · **Stand:** 2026-06-05
**Engine:** Keygen CE (self-hosted, kommerziell kostenlos) · **Standard:** siehe `Nerdsmiths_Licensing_Standard.md`

Dieser Brief ist die Referenz, die du Codex GodMode an die Hand gibst. Er beschreibt **was**
nerdkey ist und **was die erste Session (L1)** liefern soll. Der Startprompt steht am Ende.

---

## Was ist nerdkey?

Der zentrale, produkt-unabhängige **Lizenz- und Aktivierungs-Service** von Nerdsmiths.
Eine Lösung für **alle** Mac- und Windows-Produkte. Drei Bausteine:

1. **Service** (dieses Repo `nerdkey`): self-hosted Keygen CE + dünne Integrations-/Admin-Schicht.
   Einzige Wahrheit über Lizenzen, Aktivierungen, Seats, Widerruf.
2. **Shop-Anbindung** (im Repo `Nerdshmiths_LP`, später): Stripe-Webhook → Lizenz ausstellen.
3. **Client-SDK** (`nerdkey-kit`, später): Swift (macOS) + .NET/C++ (Windows), Aktivierung & Start-Check.

> nerdkey = Baustein 1 (+ optional das SDK als Unterordner `kit/`). Bausteine 2–4 sind eigene Sessions.

## Architektur-Prinzipien (verbindlich)

- **Offline-first:** Ed25519-signierte Lizenzdatei; App prüft Signatur lokal bei jedem Start +
  periodischer Online-Re-Check (3–7 Tage) mit Grace-Period.
- **Seat-Modell:** Aktivierung bindet an Maschinen-Fingerprint; Server erzwingt Limit; Deaktivieren gibt Seat frei.
- **Signing-Keys NIE auf dem Download-/Web-Server** — Secret-Manager/Server-Env, nicht im Repo.
- **Refund → Revoke** (Anschluss an Stripe `charge.refunded`, später in L2).
- **Plattform-Signing** (macOS Developer ID/Notarisierung, Windows Authenticode) ist Dennis-Aufgabe, nicht Teil von nerdkey.

---

## ⭐ Primäres Nutzungsziel (oberste Priorität: Easy to use)

nerdkey muss im Alltag **trivial** zu bedienen sein. Konkret:

- **Neues Produkt / neue Lizenz hinzufügen = EIN Config-Eintrag + EIN Befehl.** Kein Hand-API-
  Gefummel, keine verstreuten Schritte. Beispiel-Zielbild:
  `nerdkey product add --slug meinapp --seats 2` bzw. ein neuer Block in `products.yaml` →
  `nerdkey apply`.
- **Eine zentrale, gut kommentierte Konfigurationsdatei** (z.B. `products.yaml` / `policies.yaml`)
  als Single Source of Truth für alle Produkte, Seats, Lizenzmodelle.
- **Idempotent & wiederholbar:** `apply` erneut ausführen ändert nichts Unerwartetes.
- **Lizenz ausstellen / sperren / auflisten** je als ein klarer Befehl (`nerdkey license issue|revoke|list`).
- **Gut dokumentiert:** README mit Copy-Paste-Beispielen für die 5 häufigsten Aufgaben.
- **Robust:** klare Fehlermeldungen, Health-Check, Backup/Restore mit einem Befehl.

> Messlatte: Dennis kann ein neues Produkt in unter 2 Minuten anlegen, ohne die Keygen-API-Doku zu öffnen.

---

## Scope der ERSTEN Session = Phase L1

**Ziel:** Keygen CE als self-hosted Lizenz-Server produktionsreif und reproduzierbar aufsetzen,
in einem sauber bootstrappten `nerdkey`-Repo.

**Lieferumfang L1:**
1. Repo-Governance bootstrappen (greenfield): AGENTS.md/Repo-Regeln, `main`-Branch, Struktur.
2. Keygen CE via **Docker Compose** (API + Postgres + Redis) nach offizieller Self-Hosting-Doku
   (keygen.sh/docs/self-hosting). LTS-Image-Tag pinnen. `.env.example` mit allen nötigen Vars.
3. **Ed25519-Signing-Keypair** erzeugen — Anleitung + Script; PRIVATE Key nur in Server-Env/Secret,
   **niemals committen**; Public Key dokumentieren (kommt später in die Apps).
4. **Produkt-Registry als zentrale Config** (`products.yaml` o.ä.) + **`apply`-Befehl**, der die
   Keygen-Policies idempotent erzeugt/aktualisiert: perpetual license, activation/machine limit =
   Seats (Default 2), Fingerprint-Strategy, node-locked. Single Source of Truth für alle Produkte.
5. **Admin-CLI** (CE hat keine UI) mit klaren Befehlen: `product add`, `apply`,
   `license issue|revoke|list`, plus **Backup/Restore** für die Keygen-Postgres-DB je ein Befehl.
   Admin-Token nur aus `.env`. (Siehe „Primäres Nutzungsziel" oben — das ist das Akzeptanz-Herzstück.)
6. **README**: Setup, Env-Vars, Policy-Schema, Backup/Restore, lokaler Smoke-Test
   (API hochfahren, Health-Check, Test-Lizenz anlegen + validieren).

**Done when (Akzeptanzkriterien):**
- `docker compose up` bringt Keygen CE lokal hoch; Health-Check grün.
- **Neues Produkt hinzufügen = ein Eintrag in `products.yaml` + `nerdkey apply`** (≤ 2 Min, ohne API-Doku).
- Eine Test-Lizenz lässt sich per CLI anlegen (`license issue`), **validieren**, auflisten und sperren.
- Maschinen-Aktivierung gegen Seat-Limit getestet (2 Aktivierungen ok, 3. abgelehnt).
- Keine Secrets im Repo; `.env.example` vollständig; Backup/Restore je ein Befehl, dokumentiert.
- README mit Copy-Paste-Beispielen für die 5 häufigsten Aufgaben; Dritter kann ohne Rückfragen aufsetzen.

**Explizit NICHT in L1:** Shop-/Stripe-Anbindung (L2), Client-SDK (L3), Auto-Updates (L4).

---

## Codex GodMode — Startprompt (kurz)

> Greenfield-Repo → `$greenfield-bootstrap` mit dazunehmen. Lean starten, Orchestrator skaliert selbst.

```text
$godmode-workflow
$greenfield-bootstrap

Goal: nerdkey aufsetzen — self-hosted Keygen CE als Nerdsmiths Lizenz-/Aktivierungs-Service (Phase L1).

Context:
- Greenfield-Repo cubetribe/nerdkey (noch leer). Zuerst Repo-Governance bootstrappen, Branch main.
- Engine ist entschieden: Keygen CE, self-hosted, kommerziell kostenlos. Keine eigene Krypto erfinden.
- Architektur & Prinzipien: docs/BUILD_BRIEF.md (dieser Brief) und docs/Nerdsmiths_Licensing_Standard.md.
- OBERSTE PRIORITAET = Easy to use: neues Produkt/neue Lizenz hinzufuegen muss EIN Config-Eintrag
  (products.yaml) + EIN Befehl (nerdkey apply) sein. Zentrale Config als Single Source of Truth, CLI
  mit klaren Befehlen (product add, apply, license issue|revoke|list), gut dokumentiert.
- Offizielle Doku: https://keygen.sh/docs/self-hosting
- Prinzipien: Ed25519-Lizenzdateien, Seat-Modell via Maschinen-Aktivierung (Default 2 Seats),
  Signing-Keys NIE im Repo, Policy-as-Code je Produkt.
- Stack: Docker Compose (Keygen API + Postgres + Redis) + dünnes Admin-CLI. Secrets nur via .env.

Done when:
- docker compose up bringt Keygen CE lokal hoch, Health-Check grün.
- Neues Produkt hinzufuegen = Eintrag in products.yaml + nerdkey apply (<= 2 Min, ohne API-Doku).
- Lizenz per CLI anlegbar/validierbar/auflistbar/sperrbar; Seat-Limit erzwungen (2 ok, 3. abgelehnt).
- Ed25519-Keypair-Erzeugung dokumentiert; keine Secrets im Repo; .env.example vollständig.
- Backup/Restore je ein Befehl, dokumentiert.
- README mit Copy-Paste-Beispielen fuer die 5 haeufigsten Aufgaben.
- NICHT in dieser Session: Shop/Stripe-Anbindung, Client-SDK, Auto-Updates.
```

---

## Folge-Sessions (Kontext, nicht jetzt)
- **L2** Shop ↔ nerdkey (Repo `Nerdshmiths_LP`): Stripe-Webhook stellt Lizenz aus, Konto zeigt Key.
- **L3** `nerdkey-kit` SDK: Swift + .NET/C++, Aktivierung + Start-Check, Pilot in PolyWavConverter.
- **L4** Auto-Updates: Sparkle (macOS) + WinSparkle (Windows), EdDSA-signierte Appcasts.

Voller Plan: `Nerdsmiths_Licensing_Standard.md` §8 · Status: `ROADMAP.md` (Workstream Lizenz-Service).
```
> █ Ende.
```
