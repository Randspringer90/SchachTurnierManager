# Release Operations, Installation und lokale Secrets

Stand: 0.54.1

## Zielbild

Der SchachTurnierManager soll als eigenständiges lokales Produkt nutzbar sein:

1. Entwickler bauen und testen im Repository.
2. Turnierleiter erhalten ein Desktop-/Portable-Paket oder später eine Setup-EXE.
3. Arbeitskollegen können ohne Node/npm/.NET-Wissen per Doppelklick starten.
4. Logs, Dumps, Testausgaben und Release-Prüfungen landen in einem Run-Ordner unter `D:\Temp` und werden als ein ZIP weitergegeben.
5. Secrets bleiben lokal im Projektordner, sind DPAPI-verschlüsselt und werden nicht committed.

## Release-Artefakte

| Artefakt | Zielgruppe | Status |
|---|---|---|
| `output/desktop/SchachTurnierManager.bat` | normale Windows-Nutzer | self-contained, kein .NET beim Nutzer nötig |
| `output/SchachTurnierManager_Desktop_<version>.zip` | ZIP-Verteilung | klickbarer Start über BAT |
| `output/portable/Start-SchachTurnierManager.bat` | portable Tests/USB/Frischordner | Daten lokal im Paketordner |
| `output/installer/SchachTurnierManager_Setup_<version>.exe` | Kollegen-/Vereinsinstallation | benötigt lokal Inno Setup 6; Produktionsrelease wird explizit Authenticode-signiert |

## Standardprüfung

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Das Skript erzeugt am Ende `UPLOAD_ZIP=...` und enthält:

- ReleaseGate
- Secret-Safety-Selftest
- Desktop-Publish
- portable Self-contained-Paketierung
- optional Installer-Readiness
- GitSafety
- Release-Artefaktmanifest mit SHA256
- Release-Trust-Readiness mit maschinenlesbarem `manual-only`-Update-Manifest

Für einen echten Produktionskandidaten kommt Authenticode-Signierung hinzu. Sie ist **nie**
automatisch aktiv und benötigt einen expliziten lokalen Zertifikat-Thumbprint plus
`-RequireSignedArtifacts`. Details: [`../release/SIGNING_AND_UPDATES.md`](../release/SIGNING_AND_UPDATES.md).

## Logging

Die WebApi nutzt `appsettings.json` und `appsettings.Development.json`:

- `SchachTurnierManager=Information` im Normalbetrieb
- `SchachTurnierManager=Debug` in Development
- Microsoft/EF standardmäßig reduziert, um Turniertag-Logs lesbar zu halten
- HTTP-Logs enthalten keine Querystrings und keine Secrets

## Lokale Secrets

Echte Secrets gehören nicht ins Repository. Wenn später KI-Provider/BYOK angebunden werden, gilt:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-LocalSecret.ps1 -Name OpenAI.ApiKey
```

Ablage:

```text
.secrets/local/OpenAI.ApiKey.dpapi.txt
```

Die Datei liegt innerhalb des Projektordners, ist aber gitignored und per Windows-DPAPI an den aktuellen Windows-Benutzer gebunden.

## Agenten-/Skill-Struktur

Relevante Skills:

- `.agents/skills/release-operations.md`
- `.agents/skills/logging-observability.md`
- `.agents/skills/repository-security.md`
- `.agents/skills/installer-packaging.md`

Neue Codex-/Claude-Läufe sollen diese Skills lesen, bevor sie an Packaging, Logging, Secrets oder Release arbeiten.
