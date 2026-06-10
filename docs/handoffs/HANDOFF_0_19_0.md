# Handoff 0.19.0

## Ziel

v0.19.0 ergänzt die Swiss-Chess-Paritätsmatrix und legt damit die langfristige Funktions-Roadmap fest. Diese Version enthält bewusst primär Dokumentation und Versionspflege, damit die weitere Entwicklung nicht nur inkrementell, sondern gegen eine vollständige Zielmatrix läuft.

## Inhalt

- `docs/SWISS_CHESS_PARITY_ROADMAP.md`
- `CHANGELOG.md`-Eintrag für 0.19.0
- Versionen in API/Dashboard/package.json/package-lock.json auf 0.19.0
- vollständige Nachkontrolle: restore, build, test, Frontend-Build, Portable-Paket

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.19.ps1"
```

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add Swiss-Chess parity roadmap"; git push
```
