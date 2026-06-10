# Aktueller Zusatz 0.12.0

- Externe Profile können auf Dubletten geprüft und als neuer oder bestehender Teilnehmer angewendet werden.
- DSB/DeWIS bleibt nächster Integrationsblock nach Klärung der offiziellen Schnittstelle.

# Roadmap

## Kurzfristig
1. v0.2-ZIP einspielen.
2. `scripts\Test-All.ps1` ausführen.
3. Lokalen Smoke-Test: Backend + Dashboard starten, Turnier anlegen, Spieler eintragen, Runde auslosen, Ergebnis speichern.
4. Commit und Push nach erfolgreichem Test.

## Mittelfristig
1. Teilnehmer bearbeiten/löschen im Dashboard.
2. CSV/JSON Import/Export.
3. Kreuztabelle.
4. Kategorien und Heldenpokal im UI.
5. Pairing-Golden-Tests mit realistischen Schweizer-Turnierfällen.

## Langfristig
1. FIDE-Dutch-Swiss so weit wie möglich regelkonform.
2. Swiss-Chess/Swiss-Manager/Chess-Results Adapter.
3. Portable Release und Windows-Installer.
4. PWA/Handy-App-Modus.


## 0.5.0

Manuelle Paarungsänderungen, Rundensperren, Prüfstatus und Checkpoint-Commits.


## 0.8.0

Portable lokale Anwendung: Backend hostet Dashboard, Pack-Skript erzeugt `output\portable` und optional ZIP-Paket.

## Danach

Klassischer Windows-Installer, Update-Workflow, Release-Checkliste und FIDE-Dutch-Swiss-Annäherung.


## 0.9.1

- Konfigurierbare Turniereinstellungen und Wertungskette.
- Punktesysteme, TWZ-Quelle, Forfeit-/Bye-Policy und Heldenpokal-Mindestpartien im UI.

## 0.10.0 geplant

- Turnierassistent, Importvorschau, Validierungen und Exportcenter.


## Externe Spielerdaten-Anbindung

Kurzfristig: FIDE-ID-Direktabruf und Mapping in Teilnehmerdaten. Danach DSB/DWZ-Anbindung über offizielle Schnittstellen und ThSB-Kontext über Verband-/Vereinsfilter.


## Nächste Schritte nach v0.10.0

- FIDE-Namenssuche sauber prüfen und ggf. aktivieren.
- DSB/DeWIS-API-Zugang klären.
- ThSB über DSB/DeWIS-Verbands-/Vereinsfilter integrieren.
- Import-Vorschau und Dublettenprüfung für externe Treffer ergänzen.
