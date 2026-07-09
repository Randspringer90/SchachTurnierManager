# Report: RUN-03 Portable-Manifest TrimStart-Hotfix

## Ergebnis

Der RUN-03-Frischordner-Test war bis `releasegate-skip-pack` und `pack-portable` erfolgreich,
brach aber danach beim Erstellen der Portable-Manifest-Liste ab. Die Ursache lag in
`TrimStart('\\','/')`: PowerShell bekam fuer den Backslash kein einzelnes `char`, sondern
einen ungueltigen Stringwert.

## Anpassungen

- `scripts/Invoke-PortableFreshFolderTest.ps1` nutzt nun explizit:
  - `[char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)`
  - Regex-basierte Pfadsegment-Zaehlung fuer `\` und `/`
- `data` bleibt optionaler leerer ZIP-Ordner.
- Version auf `0.44.2` erhoeht.

## Verifikation

Lokal in diesem Paket nicht ausgefuehrt; bitte auf Marcos Windows-Workstation erneut ausfuehren:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortableFreshFolderTest.ps1
```

Erwartung: ReleaseGate OK, Pack-Portable OK, Manifest OK, Smoke gegen Health/Dashboard/API OK,
`UPLOAD_ZIP=...` am Ende.
