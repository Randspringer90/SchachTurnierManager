# Handoff 0.21.0 - Pairing-Audit mit Qualitätsbericht

## Ziel

Der Pairing-Qualitätsbericht ist nicht mehr nur ein separater Prüfbutton im Dashboard, sondern wird bei jeder automatisch erzeugten Runde direkt ins Runden-Audit geschrieben. Damit sieht die Turnierleitung sofort, warum eine Auslosung fachlich plausibel oder auffällig ist.

## Inhalt

- `TournamentService.GenerateNextRound(...)` erweitert die erzeugte Runde vor dem Speichern um einen Pairing-Quality-Auditblock.
- Audit-Meldungen enthalten Qualitätswert, Schweregrad, Rematches, Scoregruppenabweichungen, Farbfolgenrisiken und Byes.
- Application-Workflow-Tests prüfen automatische Audit-Erweiterung.
- Domain-Golden-Szenarien prüfen stabile Swiss-Pairing-Verläufe über zwei Runden und Bye-Audit.

## Nachkontrolle

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Nächster sinnvoller Schritt

v0.22.0 sollte den Schweizer-System-Kern fachlich verbessern: Kandidatenliste je Scoregruppe, sichtbare Pairing-Kandidaten/Penalty-Begründung und bessere Floater-Erklärung.