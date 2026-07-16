# Modellrouting (qualitaetsklassenbasiert)

Das Repository routet Aufgaben ueber stabile logische Profile und Qualitaetsklassen. Es
enthaelt weder schnell veraltende Modellversionspins noch provider- oder maschinenspezifische
Pfade. Die aufrufende Runtime ordnet ein logisches Profil einem tatsaechlich verfuegbaren
Modell zu und muss dessen Verfuegbarkeit vor Beginn bestaetigen.

Kanonische Quellen:

- `config/agent-routing.json`: Agentenrollen, Taskkategorien und Mindestqualitaet.
- `config/model-routing.json`: geordnete Auswahlregeln und logische Profile.
- `config/model-routing.schema.json`: fail-closed Policy-Schema.
- `scripts/Resolve-ModelRoute.ps1`: reproduzierbarer Resolver ohne Modellausfuehrung.
- `scripts/Test-ModelRoutingReadiness.ps1`: Policy- und Entscheidungsmatrix.

## Logische Profile

| Profil | Einsatz |
|---|---|
| Fabel | Orchestrierung, Paketzerlegung, Resume und Handoff |
| Sol | grosse Planung, Architektur und Finalintegration |
| Luna | klar definierte grosse Implementierung ausserhalb kritischer Fachkategorien |
| Terra | ausschliesslich risikoarme, deterministische Massenarbeit |
| Opus | Security, Schachregeln, Pairing/Tie-Breaks, Release, Installer und schwierige Reviews |
| Sonnet | klar abgegrenzte Implementierung kleinen oder mittleren Umfangs und hoechstens mittleren Risikos |

Die Namen sind logische Ausfuehrungsprofile, keine konkreten Modell-IDs. Eine Runtime darf
sie nur auf Modelle abbilden, welche die geforderte Qualitaetsklasse tatsaechlich erfuellen.

## Entscheidungsablauf

1. Aufgabe nach Kategorie, Arbeitsmodus, Umfang, Risiko und Determinismus klassifizieren.
2. Regeln in aufsteigender `priority` auswerten.
3. Risiko-, Determinismus- und Mindestqualitaetsgrenzen des Profils pruefen.
4. Verfuegbare logische Profile explizit an den Resolver uebergeben.
5. Entscheidung mit Regel, Profil, Status und Begruendung protokollieren.

Beispiel:

```powershell
pwsh scripts/Resolve-ModelRoute.ps1 `
  -TaskCategory security -WorkMode review -Size medium -Risk critical `
  -AvailableProfiles opus,sol,sonnet
```

## Fail-closed-Regeln

- Qualitaet hat Vorrang vor Kosten.
- Security, Schachregeln, Pairing, Tie-Breaks, Release, Installer und schwierige
  PR-Finalfreigaben bleiben beim staerksten Expertenprofil.
- Fehlt das erforderliche Profil, wird mit `BLOCKED_PROFILE_UNAVAILABLE` beendet. Es gibt
  keinen automatischen oder stillen Fallback.
- Ohne bestaetigte Profilverfuegbarkeit wird mit `BLOCKED_AVAILABILITY_UNVERIFIED` beendet.
- Passt keine sichere Regel, ist eine explizite Owner-Entscheidung erforderlich.
- `securityReviewRequired` und `humanApprovalRequired` aus dem Agentenrouting bleiben
  zusaetzliche, unabhaengige Gates.
