# Handoff 0.11.1 - FIDE-Test und Ticket-Vorbereitung stabilisiert

## Inhalt

- FIDE-Provider-Test korrigiert: `RequestUri` wird als absolute URI geprüft.
- Issue-Templates für GitHub ergänzt:
  - `.github/ISSUE_TEMPLATE/bug_report.yml`
  - `.github/ISSUE_TEMPLATE/feature_request.yml`
  - `.github/ISSUE_TEMPLATE/config.yml`
- Ticket-/Feedback-Workflow dokumentiert in `docs/TICKETS_AND_FEEDBACK.md`.
- Versionen auf `0.11.1` gesetzt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.11.1.ps1"
```

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize FIDE lookup tests and add issue templates"; git push
```
