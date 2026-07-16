# Erster Beitrag – Schritt für Schritt

> Für den neu eingeladenen Mitwirkenden. Setzt ein abgeschlossenes
> [`COLLABORATOR_ONBOARDING.md`](COLLABORATOR_ONBOARDING.md) voraus.
>
> **Arbeitest du mit Codex an Schach-Features?** Nutze die einfache Anleitung
> [`CODEX_CHESS_CONTRIBUTOR.md`](CODEX_CHESS_CONTRIBUTOR.md) und erzeuge den fertigen
> Arbeitsauftrag mit `pwsh scripts/New-ContributorTaskPrompt.ps1 -BacklogId STM-…`.

## 1. Aufgabe wählen

- Öffne [`../planning/BACKLOG.md`](../planning/BACKLOG.md).
- Wähle **einen** Eintrag mit Status **`Ready`** (nur diese sind freigegeben).
- Öffne das verlinkte GitHub-Issue und weise es dir zu.

## 2. Status setzen

- Backlog-Eintrag: Status → `In Progress`, deinen Namen als Bearbeiter, geplanten Branchnamen
  und Issue-Nummer eintragen (im selben oder ersten PR-Commit).

## 3. Feature-Branch erzeugen

```powershell
pwsh scripts/New-FeatureBranch.ps1 -BacklogId STM-XXXX-000 -Name kurz-name
```

Das Skript prüft die Backlog-ID, validiert den Namen (`[a-z0-9-]`), zweigt sauber von
`origin/development` ab und blockt unsichere Namen.

## 4. Umsetzen

- Code **und** Tests **und** Doku.
- Lokal grün halten:
  ```powershell
  pwsh scripts/Test-All.ps1
  pwsh scripts/Invoke-ReleaseGate.ps1
  ```
- Commit über `scripts/Commit-If-Green.ps1` (stoppt bei rotem Gate).

## 5. Vor dem PR aktualisieren

```bash
git fetch origin
git merge origin/development     # Konflikte lokal lösen, kein Force-Push
```

## 6. Pull Request öffnen

```bash
git push -u origin feature/STM-XXXX-000-kurz-name
gh pr create --base development --fill
```

**Ohne `gh` installiert:** funktioniert genauso über die Weboberfläche. Nach `git push`
zeigt die Konsole einen direkten Link zum PR-Formular an (auch abrufbar über
`https://github.com/Randspringer90/SchachTurnierManager/pull/new/<dein-branch>`). Dort
**base auf `development`** prüfen (GitHub schlägt oft automatisch `main` vor), Titel/Text
ausfüllen, „Create pull request" klicken.

- PR-Template **vollständig** ausfüllen: Backlog-ID, Issue, Ausgangs-/Zielbranch, Tests,
  ReleaseGate-Ergebnis, Security-Check, Prompt-Injection-Check, Doku-/Backlog-Änderungen,
  Breaking-Change, Screenshots bei UI, Bestätigung „keine Secrets/Logs/PII/Artefakte".
- Backlog-Status → `In Review`.

## 7. Review abwarten

- der Owner (CODEOWNER) reviewt. CI muss grün sein, alle Konversationen gelöst.
- Nach neuen Commits kann eine erneute Freigabe nötig sein.

## 8. Merge & Abschluss

- der Owner merged per **Squash** nach `development`; der Branch wird automatisch gelöscht.
- Backlog-Status → `Done`, `CHANGELOG.md` aktualisiert.

## Wenn etwas unklar ist

Frage im Issue nach – **rate nicht** bei Pairing-Logik, Wertungen oder Sicherheitsthemen.
Auditierbarkeit der Pairing-/Wertungsentscheidungen hat Vorrang.
