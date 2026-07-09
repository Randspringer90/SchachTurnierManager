# Prompt - RUN-03 Portable data folder hotfix

## Anlass

Der RUN-03-Frischordner-Test baute ReleaseGate und Portable-Paket erfolgreich, brach aber
im Manifest ab, weil ein leerer `data`-Ordner im ZIP erwartet wurde. Leere Ordner werden
von `Compress-Archive` nicht verlaesslich in ZIP-Dateien uebernommen.

## Anpassung

- `data` im Portable-ZIP ist optional; der Test verwendet fuer den Runtime-Smoke einen
  separaten isolierten Datenordner im Run-Verzeichnis.
- Portable-Root wird anhand `Start-SchachTurnierManager.bat` erkannt.
- Manifest schreibt WARN statt FEHLT fuer optionale leere Ordner und listet relevante
  Paketdateien.

## Verifikation

Vom Nutzer auszufuehren:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortableFreshFolderTest.ps1
```

Erwartung: ReleaseGate, Pack-Portable und Portable-Smoke sind OK; am Ende wird
`UPLOAD_ZIP=...` ausgegeben.
