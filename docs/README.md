# nerdkey – docs/

Referenz-Dokumentation für den Nerdsmiths Lizenz-/Aktivierungs-Service.

| Datei | Inhalt |
|-------|--------|
| `BUILD_BRIEF.md` | **Hier starten.** Was nerdkey ist, verbindliche Prinzipien, Scope der ersten Session (L1) inkl. Akzeptanzkriterien und Codex-GodMode-Startprompt. |
| `Nerdsmiths_Licensing_Standard.md` | Firmenweiter Lizenz-Standard 2026: Architektur, Best Practice (Mac+Windows), Engine-Entscheidung (Keygen CE), voller Bauplan L1–L4. |
| `Nerdsmiths_ROADMAP.md` | Gesamt-Roadmap (Shop + Lizenz-Service-Workstream) als Statuskontext. |

## Kernanforderung (oberste Priorität)

**Easy to use:** Ein neues Produkt / eine neue Lizenz hinzuzufügen muss **ein Config-Eintrag
(`products.yaml`) + ein Befehl (`nerdkey apply`)** sein. Zentrale Config als Single Source of
Truth, klares Admin-CLI, gut dokumentiert. Messlatte: neues Produkt in < 2 Minuten, ohne API-Doku.

## Schnellstart (Codex GodMode)

Session in diesem Repo öffnen und den Startprompt aus `BUILD_BRIEF.md` (Abschnitt „Codex GodMode –
Startprompt") abfeuern. `$greenfield-bootstrap` legt zuerst die Repo-Governance an, dann baut
GodMode Phase L1 (Keygen CE self-hosted).

## Engine-Lizenz

Keygen CE ist self-hosted und **kommerziell kostenlos** (Fair Core License). Details im Standard.
