# Report 2026-07-09 – RUN-03 Portable-ZIP-Frischordner-Test

## TL;DR

RUN-03 wurde als prüfbarer, ruhiger Verifikationslauf umgesetzt. Das neue Skript baut optional
ein self-contained Portable-ZIP, entpackt es in einen frischen Ordner unter `D:\Temp`, startet
die WebApi auf einem Testport und prüft Health, Dashboard, Turnierlisten-API sowie den
SQLite-Datenpfad im isolierten Testdatenordner.

## Geänderte Dateien

- `scripts/Invoke-PortableFreshFolderTest.ps1`
- `scripts/README.md`
- `README.md`
- `PLANS.md`
- `CHANGELOG.md`
- `docs/ai/PROMPTS.md`
- `docs/ai/prompts/2026-07-09-chatgpt-run03-portable-fresh-folder.md`
- `docs/ai/reports/2026-07-09-chatgpt-run03-portable-fresh-folder.md`
- `src/SchachTurnierManager.WebApi/Program.cs`
- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`

## Tests

In ChatGPT nicht lokal auf lokaler Windows-Workstation ausgeführt. Erwartete Verifikation:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortableFreshFolderTest.ps1
```

## Risiken / Grenzen

- Der Smoke nutzt standardmäßig Port `5098`. Bei belegtem Port per `-Port` anderen Port wählen.
- Der Test startet die WebApi direkt aus dem entpackten `app`-Ordner, nicht über die BAT, damit
  der Testport frei wählbar bleibt und nicht mit 5088 kollidiert.
- Der Lauf erzeugt bewusst lokale `output/`- und `D:\Temp`-Artefakte; diese bleiben uncommitted.

## Nächster Schritt

Nach grünem RUN-03-Smoke: Commit über `Commit-If-Green.ps1`. Danach entweder echten
Inno-Setup-Test abschließen, RUN-02 Release-Reife-Audit oder RUN-21/i18n-Bereichsextraktion.
