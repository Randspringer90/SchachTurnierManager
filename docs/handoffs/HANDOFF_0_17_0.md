# Handoff 0.17.0 - Pairing-Qualitätsbericht

## Ziel

v0.17.0 ergänzt eine erste fachliche Qualitätsanalyse für erzeugte/zu prüfende Schweizer-System-Paarungen.

## Enthalten

- `PairingQualityReport`
- `PairingQualityBoard`
- `PairingQualitySeverity`
- `PairingQualityAnalyzer`
- Tests für:
  - saubere erste Runde,
  - Rematches,
  - unterschiedliche Scoregruppen,
  - dritte gleiche Farbe in Folge,
  - Bye/Spielfrei.

## Bewusst noch nicht enthalten

- UI-Darstellung des Qualitätsberichts.
- API-Endpunkt für Qualitätsberichte.
- Vollständiger FIDE-Dutch-Algorithmus.

Das folgt in den nächsten Versionen. Dieser Patch legt zuerst eine testbare fachliche Grundlage, damit die Erklärung „Warum wurde so gelost?“ später aus einem stabilen Modell gespeist werden kann.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.17.ps1"
```

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add pairing quality analyzer"; git push
```
