# Zentraler Modellkatalog: Zwischenabschluss

Datum: 2026-10-04. Owner-Auftrag und nachtraegliche Architektur-/Modellfreigabe siehe
[Prompt](../prompts/20261004_1854_all-prs-model-catalog.md).

Konkrete Modellvarianten stehen ausschliesslich in `config/model-catalog.json`.
Offizielle Modellquellen wurden am 2026-10-04 geprueft:
[OpenAI](https://developers.openai.com/api/docs/models),
[Anthropic](https://platform.claude.com/docs/en/models/overview).
Stable Profile bleiben erhalten; Sol und das grosse Implementierungsprofil Luna
teilen die leistungsfaehige Variante, Terra verwendet die effiziente Variante.
Keine CLI-Updates, Modellinferenz, kostenpflichtigen API-Wechsel oder Login-Aenderungen.
Account-Verfuegbarkeit muss weiterhin die ausfuehrende Runtime bestaetigen.

## Reale Verifikation

- Ausgangstest RED: `runtime-uses-catalog`, Exit 1.
- Unabhaengiger statischer Review fand inkonsistente Aufloesung relativer Policy-Pfade;
  Regressionstest RED mit verschiedener PowerShell-Location und Prozess-CWD, Exit 1.
  Korrektur ueber PowerShell-Path-API; unabhaengiger Re-Review PASS ohne verbleibende Must-fix-Funde.
- Katalog-Readiness: 25/25 Checks, Exit 0, einschliesslich Provider-Grenzen,
  unbekannter Schluessel, Inline-IDs, unsicherer IDs/Quellen, fehlendem Schema,
  echter Ancestor-Junction und Sol/Luna-Mitlauf bei reinem Katalogupdate.
- Model-Routing: 12 Entscheidungsfaelle, Exit 0. Routed-Execution: 34 Checks,
  Exit 0; der neue Katalogtest ist zusaetzlich eingebunden.
- Prompt-Injection-, Instruction-Integrity-, GitCommitSafety- und OpenSourceSafety-Gates:
  Exit 0. Instruction-Integrity verlangte erwartungsgemaess Tracking des neuen Katalogs;
  nach expliziter Aufnahme in Git wurde erneut erfolgreich geprueft.
- ReleaseGate mit `-SkipPack -NoNpmInstall` nach separatem `npm ci`: Exit 0.
  .NET-Build: 0 Fehler, 6 Warnungen. .NET-Tests: 516 bestanden, 0 Fehler/Skipped
  (Golden 13, Application 108, Infrastructure 20, Domain 375).
  TypeScript-/Vite-Build erfolgreich. Im aktuellen Frontend-package.json existiert
  kein separater Testbefehl; neue Frontend-PRs werden nach ihrem jeweiligen Scope geprueft.

17 historische Dokumente wurden versionsneutral redigiert. Die damaligen Test-,
Erfolgs- und Limitangaben bleiben historische Aussagen und wurden nicht als heutige
Modellnutzung umgedeutet. Historische Dateinamen/Links bleiben fuer Nachvollziehbarkeit erhalten.

## Noch laufende PR-Integration

Live-Start: 29 offene PRs einschliesslich #54; Start- und derzeitiger Entwicklungs-SHA:
`cc47f1101983d3f3272a893dbf54bd66fa2355b4`. Spaeter kam durch parallele Owner-Arbeit
PR #98 hinzu. Dieser ist weiterhin Draft und statisch `BLOCKED_UNVERIFIED`;
kein Code dieses PRs wurde ausgefuehrt. Modelltests/-dokumentation dort muessen auf
den zentralen Katalog abgestimmt werden. Der Gesamtauftrag ist hiermit nicht abgeschlossen.

PR #63: vollstaendig unabhaengig statisch geprueft. Bootstrap-Ausnahme muss vor
Integration enger begrenzt werden. Statische Freigabe ersetzt keine lokalen Tests oder CI.
Externe detaillierte Laufdiagnosen, synthetische Fixtures und Backups bleiben ausserhalb Git.
Commit-/Push-Ergebnisse und finale PR-Klassifikation folgen im Gesamtabschlussbericht;
sie sind hier noch nicht als erfolgreich behauptet.
