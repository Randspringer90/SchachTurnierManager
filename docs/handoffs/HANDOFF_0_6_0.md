# Handoff 0.6.0

## Ziel

v0.6.0 stabilisiert kampflose Ergebnisse, Bye-Behandlung und die Rundenprüfung.

## Umgesetzt

- `ForfeitTiebreakPolicy` in `TournamentSettings`.
- Kampflose Ergebnisse zählen weiterhin für Punkte, aber standardmäßig nicht für Buchholz, Sonneborn-Berger, Direktvergleich, Gegnerschnitt oder Performance.
- Optionale Policies für Buchholz-only bzw. normale Tiebreak-Behandlung kampfloser Ergebnisse.
- Bye zählt weiterhin als Punkt, aber standardmäßig nicht als Sieg.
- Performance- und Heldenpokalwertung berücksichtigen nur gespielte Partien.
- Neue Modelle `RoundDiagnostics` und `BoardDiagnostic`.
- Neue API-Endpunkte `/round-diagnostics` und `/rounds/{roundNumber}/diagnostics`.
- Dashboard zeigt Rundenprüfung mit offenen Brettern, kampflosen Partien, Bye und Wertungsfolgen.
- Neue Tests für Forfeit-Scoring und Round-Diagnostics.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.6.ps1"
```

Danach committen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Clarify forfeit scoring and round diagnostics"; git push
```
