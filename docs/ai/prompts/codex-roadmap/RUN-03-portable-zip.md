# RUN-03 – Portable ZIP produktionsreif machen

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ausgangslage
`scripts/Pack-Portable.ps1` und `scripts/Start-Portable.bat` existieren und laufen im
Release-Gate. Offen ist der Nachweis „funktioniert beim Endnutzer ohne Entwicklerwerkzeuge".

## Aufgaben
- Vollständiges Release-Gate (ohne `-SkipPack`) laufen lassen; ZIP unter `output\` prüfen.
- ZIP in einen frischen Ordner (außerhalb des Repos) entpacken und nur per
  `Start-SchachTurnierManager.bat` starten: Health, Dashboard, Turnier anlegen,
  Runde auslosen, Backup erzeugen.
- README-Portable.md auf Endnutzer-Tauglichkeit prüfen (Sprache, Backup-Hinweise,
  Datenordner, Deinstallation = Ordner löschen).
- Framework-dependent vs. self-contained klar dokumentieren (Default sollte für
  Endnutzer ohne .NET funktionieren → ggf. `-SelfContained` zum Default machen).

## Ergebnis
Getestetes ZIP-Verfahren, dokumentiert in README + Bericht. ZIPs selbst nie committen.
