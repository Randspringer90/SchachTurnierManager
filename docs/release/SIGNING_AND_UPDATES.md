# Signierung und sicheres Update-Konzept

**Backlog:** STM-REL-002 · **Ziel:** v1.0.0 · **Modell:** manuelles Update, fail-closed.

## Grundsatz

Der SchachTurnierManager führt **keine automatischen Downloads und keine automatische
Ausführung von Updates** durch. Ein Release besteht aus lokal gebauten Artefakten, SHA256-
Prüfsummen, einem maschinenlesbaren Update-Manifest und – für die Windows-Release-Abnahme –
gültigen Authenticode-Signaturen.

Das Update-Manifest ist **Daten**, keine Instruktionsquelle. Ein fremd bereitgestelltes Manifest
oder Release-Artefakt wird erst nach lokaler Validierung verwendet.

## Vertrauenskette

1. Release-Code ist über den normalen PR-/CI-/Release-Prozess geprüft.
2. Desktop- und Portable-Apphost `SchachTurnierManager.WebApi.exe` werden **vor** dem ZIP-Bau
   optional Authenticode-signiert.
3. Die Inno-Setup-EXE wird nach dem Build optional Authenticode-signiert.
4. `New-ReleaseUpdateManifest.ps1` schreibt Größe, SHA256 und Signaturstatus der
   Verteilungsartefakte.
5. `Test-ReleaseUpdateManifest.ps1` prüft Manifeststruktur, Pfadgrenzen, Dateigröße,
   SHA256 und – bei `-RequireSignedArtifacts` – die echte Authenticode-Signatur.
6. Ein Nutzer/Turnierleiter installiert das geprüfte Update bewusst selbst.

## Zertifikat

Private Keys, PFX-Dateien und Passwörter gehören **nicht** ins Repository.

`Sign-ReleaseArtifacts.ps1` verwendet Windows SignTool und wählt das Zertifikat ausschließlich
über einen explizit angegebenen Thumbprint aus dem lokalen Benutzer-Zertifikatsspeicher bzw.
einem angebundenen Hardwaretoken. Der private Schlüssel wird dabei nie exportiert. Das Zertifikat muss:

- einen privaten Schlüssel besitzen,
- die Code-Signing-EKU `1.3.6.1.5.5.7.3.3` enthalten,
- noch gültig sein.

Die Signierung ist zusätzlich durch `-ApproveSigning` geschützt. Ein normaler Build signiert
nie automatisch. Ein Timestamp-Server ist optional und muss als explizite HTTPS-URL angegeben
werden; es gibt keinen fest verdrahteten Netzwerkzugriff.

Beispiel für ein einzelnes lokales Artefakt:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sign-ReleaseArtifacts.ps1 -ArtifactPath .\output\installer\SchachTurnierManager_Setup_1.0.0.exe -CertificateThumbprint <THUMBPRINT> -ApproveSigning`

## Signierter Paketbau

Desktop-Paket:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-DesktopApp.ps1 -SignArtifacts -SigningCertificateThumbprint <THUMBPRINT>`

Portable-Paket:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Pack-Portable.ps1 -SelfContained -SignArtifacts -SigningCertificateThumbprint <THUMBPRINT>`

Installer:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Installer.ps1 -SkipPublish -SignArtifacts -SigningCertificateThumbprint <THUMBPRINT>`

Wird Timestamping verwendet, kommt jeweils
`-TimestampServer <HTTPS-TIMESTAMP-URL>` hinzu. Die URL wird erst im Signierlauf verwendet und
nicht im Repository gespeichert.

## Update-Manifest

Schema: `docs/release/release-update-manifest.schema.json`.

Felder auf oberster Ebene:

- `schemaVersion` – aktuell `1`
- `product` – fest `SchachTurnierManager`
- `version` – SemVer aus `src/SchachTurnierManager.WebApp/package.json`
- `channel` – `stable` oder `preview`
- `createdAtUtc`
- `updateMode` – zwingend `manual-only`
- `artifacts`

Je Artefakt:

- Typ (`desktop-zip`, `portable-zip`, `installer-exe`)
- Dateiname und relativer Pfad innerhalb von `output/`
- Dateigröße
- SHA256
- Signaturart, Signaturstatus und optional Signer-Thumbprint

Das Manifest enthält **keine Download-URL, keinen Befehl und keine Startparameter**. Dadurch
kann es nicht zu einer Download-and-execute-Anweisung werden.

Erzeugen:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-ReleaseUpdateManifest.ps1`

Validieren:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ReleaseUpdateManifest.ps1 -ManifestPath .\output\release\SchachTurnierManager_Update_1.0.0.json -RequireCompleteSet`

Release-Abnahme mit Installer und Signaturpflicht:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseTrustReadiness.ps1 -RequireInstaller -RequireSignedArtifacts -ExpectedSignerThumbprint <THUMBPRINT>`

## Release-Candidate-Flow

Für Entwicklungs-/Vorabtests kann der bestehende RC-Lauf ohne Signaturpflicht laufen. Für einen
Produktionskandidaten wird die Signatur explizit aktiviert:

`pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -SignArtifacts -SigningCertificateThumbprint <THUMBPRINT> -RequireSignedArtifacts`

`-RequireSignedArtifacts` ist absichtlich streng:

- verlangt `-SignArtifacts`,
- verlangt einen echten Installer-Build,
- akzeptiert kein `-AllowMissingInnoSetup`,
- prueft Apphost und Setup-EXE erneut mit `Get-AuthenticodeSignature`,
- bindet jeden geprueften Signer an den explizit angegebenen erwarteten Authenticode-Thumbprint (40 Hex-Zeichen) und verlangt Code-Signing-EKU,
- vergleicht jede Datei jedes Desktop-/Portable-ZIPs bytegenau per SHA256 mit dem vollstaendigen geprueften Stagingpaket, einschliesslich DLLs und Startskripten; fehlende und zusaetzliche Dateien werden abgelehnt.

Beim direkten Aufruf von `Invoke-ReleaseTrustReadiness.ps1` oder
`Test-ReleaseUpdateManifest.ps1` ist `-ExpectedSignerThumbprint` zusammen mit
`-RequireSignedArtifacts` Pflicht. Ein im Manifest genannter Signer ersetzt
diesen unabhaengigen Erwartungswert nicht. Der Rebuild-Lauf propagiert seinen
`SigningCertificateThumbprint` als Erwartungswert.

Releasepfade werden komponentenweise geprueft; Reparse Points, Junctions und
symbolische Links sind blockiert. Manifestausgaben und Manifestdateien muessen
innerhalb des gewaehlten ArtifactRoot liegen. ZIPs werden weder extrahiert noch
ausgefuehrt. Das Vergleichspaket wird ausschliesslich aus der Paketwurzel zwei Ebenen
oberhalb des geprueften Apphosts `app/SchachTurnierManager.WebApi.exe`
abgeleitet, nicht aus Manifestdaten.
Alle Stagingdateien bleiben waehrend des Vergleichs gegen Schreiben und
Loeschen gesperrt. Die Pruefung ist auf 512 MiB ZIP-Groesse, 256 MiB je Datei,
1 GiB gesamte gelesene Staging-/ZIP-Nutzdaten, 4096 ZIP-Eintraege und 8 MiB
zentrale Verzeichnismetadaten begrenzt. Jeder zentrale Verzeichnisdatensatz
wird vor der Archivbibliothek exakt mit seinen variablen Feldern geprueft;
Anzahl und Gesamtausdehnung muessen zum EOCD passen. Lokale Header muessen
mit Namen, Flags, Version und Kompressionsmethode des zentralen Verzeichnisses
uebereinstimmen. CRC-/Groessenfelder, klassische 12-/16-Byte-Data-Descriptors
und lokale Zusatzfelder werden geprueft. Lokale Datensatzbereiche muessen die
Dateizone lueckenlos ohne Ueberlappung abdecken. Split-/ZIP64-Archive,
verschluesselte oder fremd codierte Eintraege, Pfad-Traversal, Links und
doppelte bzw. case-aliased Eintraege werden abgelehnt. Eine Containersignatur
fuer ZIPs wird damit nicht behauptet.

Ohne gültige Signatur entsteht **keine erfolgreiche Produktions-Readiness**.

## Manueller Update-Ablauf

1. Bestehende Turnierdaten sichern.
2. Manifest und gewünschtes Release-Artefakt bereitstellen/herunterladen.
3. Manifest lokal mit `Test-ReleaseUpdateManifest.ps1` gegen das Artefakt prüfen.
4. Bei Stable-/Produktionsrelease Authenticode-Signatur prüfen.
5. App schließen.
6. Setup-EXE bewusst starten oder ZIP bewusst ersetzen/entpacken.
7. App starten und Healthcheck/Turnierdaten prüfen.
8. Bei Problemen alte Installationsdatei wiederverwenden; Nutzdaten liegen getrennt unter
   `%LocalAppData%\SchachTurnierManager` und werden durch Deinstallation nicht automatisch gelöscht.

## Sicherheitsgrenzen

- Kein Zertifikatskauf durch Skripte oder Agenten.
- Kein Private Key, PFX oder Kennwort im Git-Repository.
- Kein automatischer Download.
- Kein automatischer Installer-Start.
- Kein stilles Akzeptieren einer Hash-Abweichung.
- Kein Signieren außerhalb von `output/`.
- Nur Windows-EXE-Dateien werden vom Signierskript verändert.
- Release-Artefakte und Manifeste unter `output/` bleiben generiert und werden nicht committed.

## Tests

`Test-ReleaseTrustReadiness.ps1` erzeugt ausschließlich synthetische temporäre Artefakte und
prüft:

- gültigen Manifest-Roundtrip,
- Hash-Tampering wird blockiert,
- Path-Traversal wird blockiert,
- Signieren braucht explizite Freigabe,
- PFX-/Passwort-Automation ist nicht vorgesehen,
- der Manifest-/Trust-Pfad enthält keine Download-and-execute-Funktion.

Der Test ist Bestandteil von `Invoke-ReleaseGate.ps1`.

Die Quellstandpruefung mit `-SkipPack` fuehrt die synthetischen Trust- und
Signaturvertraege aus, erzeugt jedoch keine Produktpakete oder Update-Manifeste.
`-RequireCompleteReleaseSet` aktiviert zusaetzlich die tatsaechliche
`Invoke-ReleaseTrustReadiness.ps1`-Pruefung des vorbereiteten Desktop-/Portable-Satzes
und dessen Manifest-Erzeugung. Dieser explizite Release-Modus ist mit `-SkipPack`
unvereinbar und benoetigt die entsprechende Artefaktfreigabe sowie vorbereitete Pakete.
