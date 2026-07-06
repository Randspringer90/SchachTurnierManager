# RUN-05 – Installer-EXE bauen und testen

Vorab `PROMPT_BASE.md` lesen und befolgen. Setzt RUN-04 (Desktop-Paket) voraus.

## Ausgangslage (bereits vorbereitet, 2026-07-06)
- `installer/SchachTurnierManager.iss`: Inno Setup 6, Per-User ohne Adminrechte,
  Desktop-/Startmenü-Verknüpfung, Uninstaller, Sprachen de/en/es, Turnierdaten
  bleiben bei Deinstallation erhalten.
- `scripts/Build-Installer.ps1`: publiziert Desktop-Paket und ruft ISCC.exe auf.
- Offen: Inno Setup 6 ist auf dem Build-Rechner **nicht installiert**.

## Aufgaben
- Inno Setup 6 installieren (Open Source, https://jrsoftware.org/isinfo.php) –
  nur nach Freigabe des Nutzers, falls Downloads eingeschränkt sind.
- `pwsh -File .\scripts\Build-Installer.ps1` ausführen; Setup-EXE unter
  `output\installer\` erzeugen (nie committen).
- Installations-Test: installieren, per Desktop-Verknüpfung starten, Turnier anlegen,
  App schließen, erneut starten (Daten müssen da sein), deinstallieren
  (Daten unter `%LocalAppData%\SchachTurnierManager` müssen erhalten bleiben).
- Portable-ZIP-Variante parallel beibehalten (RUN-03), nichts entfernen.
- SmartScreen-/Signatur-Thema dokumentieren (unsignierte EXE → Warnung; Signierung
  ist spätere Entscheidung, keine Zertifikatskäufe ohne Freigabe).

## Ergebnis
Getesteter Installer-Workflow, dokumentiert in README + Bericht.
