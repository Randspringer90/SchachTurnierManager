# Handoff 0.30.0 – Release-Gate und Commit-Guard

## Ziel

Nach den roten Zwischenstaenden in 0.29.0/0.29.1 fuehrt 0.30.0 einen kontrollierten Release-Gate-Workflow ein. Ziel ist, dass kuenftige Commits und Pushes erst nach Restore, Build, Tests, Frontend-Build und optionaler Portable-Paketierung erfolgen.

## Neu

- `scripts/Invoke-ReleaseGate.ps1`
  - prueft auf bekannte versehentliche Dateien wie `tatus`
  - zeigt Node.js-Engine-Hinweis fuer Vite/Rolldown
  - fuehrt `dotnet restore`, `dotnet build`, `dotnet test`, `npm install`, `npm run build` aus
  - packt standardmaessig das Portable-ZIP ueber `scripts/Pack-Portable.ps1`
  - zeigt am Ende `git status --short`

- `scripts/Commit-If-Green.ps1`
  - ruft zuerst das Release-Gate auf
  - committed nur bei erfolgreichem Gate
  - pusht nur mit explizitem Parameter `-Push`

## Empfohlener Workflow

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1"
```

Commit und Push nach gruenem Gate:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "Add release gate and commit guard" -Push
```

## Hinweise

- Die bekannte npm-Engine-Warnung bei Node.js `v20.20.0` bleibt moeglich. Vite/Rolldown erwarten `^20.21.0 || >=22.12.0`.
- `Commit-If-Green.ps1` loest keine Kosten-, Cloud- oder Fremdaktionen aus. Es arbeitet nur lokal und pusht nur bei explizitem `-Push`.
- Fuer grosse Feature-Patches kann der schnellere Vorabcheck mit `Invoke-ReleaseGate.ps1 -SkipPack` genutzt werden; vor finalem Commit sollte ohne `-SkipPack` geprueft werden.
