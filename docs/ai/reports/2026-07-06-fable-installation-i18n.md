# Report 2026-07-06 – Claude Fable 5: Installation, i18n-Fundament, Codex-Roadmap

## TL;DR

Desktop-Installationspaket (self-contained, Klick-Start) gebaut und smoke-getestet,
Inno-Setup-Installer vorbereitet, i18n-Fundament für 18 Sprachen in der WebApp verankert,
Codex-Roadmap als 21 einzelne RUN-Prompts abgelegt. Release-Gate vor und nach den
Änderungen grün (175 Tests). Version 0.41.1 → 0.42.0. GitHub war nicht erreichbar –
kein Pull/Push in diesem Lauf.

## Ist-Zustand zu Beginn

- Branch `main`, Arbeitsverzeichnis sauber, HEAD `dc8d0e1`.
- Zweitcheckout `D:\Schach\SchachTurnierManager`: identischer HEAD, sauber → synchron.
- `git fetch` scheiterte: github.com:443 nicht erreichbar (kein Proxy konfiguriert).
  ahead/behind gegenüber origin daher **unbestätigt**; vor dem nächsten Push zwingend
  `git pull` + PUBLIC-Gate.
- Release-Gate `-SkipPack`: grün (Restore, Build, 175 Tests, Frontend-Build).

## Änderungen

### Installation (Roadmap-Punkte 4/5 angearbeitet)
- `scripts/Publish-DesktopApp.ps1` (neu): self-contained win-x64-Publish des Backends
  mit eingebettetem Frontend nach `output\desktop`, README-Desktop, optional ZIP.
- `scripts/Start-Desktop.bat` (neu): Klick-Start (Backend minimiert, Health-Wartefenster,
  Browser öffnet automatisch); Daten unter `%LocalAppData%\SchachTurnierManager`.
- `installer/SchachTurnierManager.iss` (neu): Inno Setup 6, Per-User ohne Adminrechte,
  Desktop-/Startmenü-Verknüpfung, Uninstaller, Turnierdaten bleiben bei Deinstallation
  erhalten, Setup-Sprachen de/en/es.
- `scripts/Build-Installer.ps1` (neu): Publish + ISCC-Aufruf mit Version aus package.json.
  **Offen:** Inno Setup 6 ist auf diesem Rechner nicht installiert → RUN-05.

### Mehrsprachigkeit (i18n-Fundament)
- `src/SchachTurnierManager.WebApp/src/i18n/`: dependency-freier Provider/Hook
  (`useI18n`, `t()` mit Interpolation), `LanguageSwitcher`, localStorage-Persistenz,
  Browsersprach-Erkennung, RTL-Unterstützung (ar), Fallback-Kette Sprache → en → de.
- 18 Sprachen registriert: de/en/es mit Kern-Schlüsselsatz übersetzt; fr, it, pt, nl, pl,
  cs, sv, da, hu, ru, uk, tr, ar, zh, ja als typisierte Stubs.
- `main.tsx`: Provider verdrahtet, Hero/Statuskarte auf `t('…')` umgestellt (Muster für
  die bereichsweise Extraktion, RUN-21), Sprachumschalter im Header, CSS ergänzt.

### Bugfixes
- Hero zeigte hartcodiert „v0.40.0" (Stand war 0.41.1) → zeigt jetzt die Live-Version
  aus dem Health-Endpoint.
- `Build-Installer.ps1`: `${env:ProgramFiles(x86)}`-Expansion korrigiert (eigener Fund
  beim Testen).

### Doku/Prozess
- `docs/ai/prompts/codex-roadmap/`: `PROMPT_BASE.md` (Arbeitsregeln), `README.md`
  (Index + Status), RUN-01 … RUN-21.
- README (Desktop-Abschnitt, i18n-Abschnitt), PLANS (0.42.0-Zusatz, v0.5-Haken),
  CHANGELOG (0.42.0), scripts/README, PROMPTS-Log.
- Version: Health-Endpoint + package.json auf 0.42.0.

## Tests / Verifikation

- Release-Gate `-SkipPack` vor Beginn: grün (175 Tests: 76 Domain, 81 Application,
  17 Infrastructure, 1 Golden).
- Frontend-Build nach i18n-Einbau: grün (tsc + vite, 35 Module).
- Desktop-Paket-Smoke: publizierte EXE auf Testport 5099 mit Temp-Datenverzeichnis
  gestartet → Health 200 (`embeddedDashboard: true`), Dashboard-Index 200; Prozess
  sauber beendet. Paketgröße ~114 MB.
- Release-Gate `-SkipPack` nach allen Änderungen: siehe Commit-Lauf (Commit-If-Green
  führt das Gate erneut aus).

## Code-Review-/Architektur-Findings (nicht in diesem Lauf behoben)

1. **`main.tsx`-Monolith (~4 000 Zeilen):** App, MobileDicePage, alle Typen und
   Hilfsfunktionen in einer Datei. Empfehlung: bei der i18n-Extraktion (RUN-21)
   bereichsweise in Module schneiden (Typen, API-Client, Bereichs-Komponenten) –
   gleiche Schnittkanten, doppelter Nutzen.
2. **npm-Dependencies auf `"latest"`:** nicht reproduzierbare Builds; auf konkrete
   Versionen pinnen (package-lock existiert, trotzdem Risiko bei frischen Installs).
   Kandidat für RUN-03/RUN-18.
3. **Kein App-Icon:** BAT-Verknüpfung ohne eigenes Icon wirkt unfertig; .ico ergänzen
   und in csproj + .iss verdrahten (RUN-04).
4. **Beenden-Erlebnis Desktop:** minimiertes Konsolenfenster als „Server" ist für
   Endnutzer erklärungsbedürftig; sauberer Shutdown-Weg prüfen (RUN-04).
5. **Port 5088 fest verdrahtet** in Start-BATs; bei Belegung nur Fehlermeldung.
   Automatische Portwahl mit Anzeige wäre robuster (RUN-04).
6. Positiv: Datenpfad-/AppData-Handling, Audit-Journal, CommitGuard und
   Secret-Hygiene (`secrets/` nur mit README getrackt) sind sauber gelöst.

## Risiken

- Installer ungetestet (Inno Setup fehlt lokal); .iss ist Standardkost, aber erst nach
  RUN-05-Test als „fertig" behandeln.
- i18n: nur Hero/Statuskarte umgestellt – UI ist bewusst noch überwiegend deutsch;
  Mischzustand ist dokumentiert und gewollt (bereichsweise Extraktion).
- Push steht aus (Netz): lokaler Commit 0.42.0 muss nach Netz-Wiederkehr gepullt/
  gemergt und erst nach PUBLIC-Gate gepusht werden.

## Nächste Schritte

1. RUN-05: Inno Setup installieren, Installer bauen, Installations-/Deinstallationstest.
2. RUN-21 (mehrfach): String-Extraktion bereichsweise + Sprachpakete füllen.
3. RUN-02: Release-Reife-Prüfung des MVP.
4. Bei Netz: `git pull`, Gates, dann Push nach Freigabe-Regeln.
