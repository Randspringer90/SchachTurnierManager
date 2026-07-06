# RUN-06 – Open-Source-Clean-Snapshot finalisieren

Vorab `PROMPT_BASE.md` und `.agents/skills/repository-security.md` lesen (verbindlich).

## Ausgangslage
`scripts/New-OpenSourceSnapshot.ps1`, `scripts/Invoke-PublicSafetySnapshot.ps1` und
`scripts/Test-RepositoryOpenSourceSafety.ps1` existieren. Offen laut PLANS: Prüfung auf
frischem Klon + manuelle Abnahme; Lizenz ist noch nicht festgelegt.

## Aufgaben
- Snapshot erzeugen und den Report vollständig durchgehen: keine `.git`-Historie,
  keine Secrets, internen URLs, Logs, Dumps, `.env`, `.npmrc`, Datenbanken, Handoffs.
- Snapshot in frischen Ordner kopieren, dort bauen und Release-Gate laufen lassen.
- Third-Party-Lizenzen inventarisieren (NuGet + npm) und Kompatibilität prüfen.
- Lizenzvorschlag begründen (MIT oder Apache-2.0), `LICENSE`-Datei vorbereiten –
  finale Wahl bestätigt der Nutzer.
- Bekanntes Risiko prüfen: `secrets/`-Ordner im Repo-Root darf nie in Snapshot/Commits.

## Nicht in diesem Lauf
- Keine Veröffentlichung, kein neues öffentliches Repo ohne ausdrückliche Freigabe.
