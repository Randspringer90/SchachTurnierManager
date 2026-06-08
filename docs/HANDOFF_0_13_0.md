# Handoff 0.13.0 - Externe Datenkonflikte

## Ziel

v0.13.0 erweitert den externen Spielerdaten-Workflow um eine explizite Konfliktanzeige im Datenmodell. Bisher wurden Dubletten erkannt und externe Profile konnten angewendet werden; jetzt wird zusätzlich sichtbar, wenn lokale Werte von externen Daten abweichen.

## Fachliche Änderungen

- Neue Konfliktmodelle:
  - `ExternalPlayerConflictSeverity`
  - `ExternalPlayerDataConflict`
- `ExternalPlayerDuplicateCheck` enthält jetzt `Conflicts` und `HasCriticalConflict`.
- `ExternalPlayerApplyResult` enthält jetzt `Conflicts`.
- Konflikte werden für wahrscheinliche Dubletten und beim Anwenden auf vorhandene Teilnehmer erzeugt.
- Kritische Konflikte: insbesondere externe IDs und Geburtsjahr.
- Warnungen: Ratings wie Elo/DWZ/Rapid/Blitz.
- Informationen: Verein, Federation, Land, Titel, DWZ-Index.

## Tests

Neue/erweiterte Tests in `ExternalPlayerApplyWorkflowTests` prüfen:

- Konflikte bei wahrscheinlicher Dublette mit FIDE-ID `4610563`.
- Geburtsjahrkonflikt als kritisch.
- Elo-Konflikt als Warnung.
- Verhalten ohne Überschreiben: lokale Werte bleiben erhalten.
- Verhalten mit Überschreiben: Konflikt zeigt `WillOverwrite = true` und externer Wert wird übernommen.

## Nachkontrolle

Ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.13.ps1"
```

Wenn grün:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add external player conflict diagnostics"; git push
```

## Nächster sinnvoller Schritt

v0.14.0 sollte die Konflikte im UI stärker herausheben und danach den CSV-Import mit Vorschau und Dublettenprüfung auf Teilnehmerlisten-Ebene angehen.
