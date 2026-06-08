# Handoff 0.9.2

## Inhalt

- Versionsbezeichnung vereinheitlicht.
- Portable-Paket liest die Version jetzt automatisch aus `src/SchachTurnierManager.WebApp/package.json` statt aus einer hart codierten Skriptvariable.
- Neues Nachkontrollskript `scripts/After-Apply-V0.9.2.ps1`.
- Planungsdokument `docs/EXTERNAL_PLAYER_LOOKUP.md` für FIDE-/DSB-/ThSB-Spielerdaten-Anbindung ergänzt.
- Agenten-Skill `.agents/skills/external-player-lookup.md` ergänzt.

## Erwartete Checks

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.9.2.ps1"
```

Danach sollte das Portable-ZIP `SchachTurnierManager_Portable_0.9.2.zip` heißen.

## Nächster Schritt

v0.10.0: Erste echte Spielerdaten-Suche mit FIDE-ID-Direktabruf, Provider-Modell und UI-Übernahme ins Teilnehmerformular.
