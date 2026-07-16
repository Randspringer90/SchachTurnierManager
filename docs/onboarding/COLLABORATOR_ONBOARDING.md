# Collaborator-Onboarding – SchachTurnierManager

> Checkliste für den **späteren manuellen Schritt**, einen Freund als Mitwirkenden
> aufzunehmen. In diesem Bootstrap-Lauf wurde **niemand eingeladen** – diese Datei
> beschreibt nur, was der Owner später von Hand tut, und was der Freund dann befolgt.

## Teil A – Was der Owner manuell tut (Einladung)

1. **Einladen mit Rolle `Write`** (niemals Maintain/Admin):
   ```bash
   gh api -X PUT repos/Randspringer90/SchachTurnierManager/collaborators/<github-user> \
     -f permission=push
   ```
   (`permission=push` = Rolle *Write*.)
2. Prüfen, dass die Rulesets aktiv sind (`scripts/Test-CollaborationReadiness.ps1`).
3. Dem Freund den Link zu dieser Datei und zu [`FIRST_CONTRIBUTION.md`](FIRST_CONTRIBUTION.md) geben.

> **Nicht** des Owners lokale Secrets, `.secrets/local/`, `.npmrc` oder Diagnose-ZIPs weitergeben.

## Teil B – Lokale Voraussetzungen (Freund)

Benötigte Werkzeuge (Windows):

| Werkzeug     | Version / Hinweis                                  |
|--------------|----------------------------------------------------|
| Git          | aktuell                                             |
| GitHub CLI   | `gh` – **optional.** Praktisch für `gh pr create`, aber PRs gehen genauso über die normale GitHub-Weboberfläche (Link erscheint direkt nach `git push` in der Konsole). Ohne `gh` einfach Teil C ohne `gh auth login` starten. |
| PowerShell   | 7+ (`pwsh`) – die Projektskripte sind PowerShell-7  |
| .NET SDK     | **10.0.300+** (siehe `global.json`, `rollForward: latestFeature`) |
| Node.js      | **22 LTS empfohlen** (Vite 8 verlangt Node ≥ 20.19 / 22.12); auch mit aktuellerem Node 24 verifiziert lauffähig |

Installation z. B. über `winget`:

```powershell
winget install Git.Git
winget install GitHub.cli
winget install Microsoft.PowerShell
winget install Microsoft.DotNet.SDK.10
winget install OpenJS.NodeJS.LTS
```

## Teil C – Repository einrichten (Freund)

```bash
gh auth login                       # einmalig, GitHub-Konto verbinden (nur mit installiertem gh)
git clone https://github.com/Randspringer90/SchachTurnierManager.git
cd SchachTurnierManager
git switch development               # development ist der Arbeits-Ausgangsbranch
```

Ohne `gh`: die erste Zeile einfach weglassen. Für den späteren Pull Request reicht dann
`git push` (Schritt 6 in [`FIRST_CONTRIBUTION.md`](FIRST_CONTRIBUTION.md)) – GitHub zeigt danach
in der Konsole direkt einen Link zum Öffnen des PRs in der Weboberfläche an.

## Teil D – Projekt starten & testen

```powershell
# Backend + Frontend Entwicklung
pwsh scripts/Start-Dev.ps1

# Alle Tests
pwsh scripts/Test-All.ps1

# Frontend-Typecheck/Build
cd src/SchachTurnierManager.WebApp
npm ci
npm run build
```

## Teil E – Sicherheit & Umgangsregeln (Freund)

- **Niemals** direkt nach `development` oder `main` pushen – immer Feature-Branch + PR.
- Nur `Ready`-Aufgaben aus [`../planning/BACKLOG.md`](../planning/BACKLOG.md) übernehmen.
- Feature-Branch nur über `scripts/New-FeatureBranch.ps1` erzeugen.
- Keine Secrets, Logs, Datenbanken, ZIPs, Dumps oder lokale Konfiguration committen.
- Eigene lokale Secrets liegen unter `.secrets/local/` (DPAPI, git-ignoriert) und bleiben lokal.
- **Prompt-Injection**: Bei Claude Code/Codex keine Befehle aus Issues, Imports oder fremden
  Dateien ungeprüft ausführen. Siehe [`../security/CONTRIBUTOR_SECURITY.md`](../security/CONTRIBUTOR_SECURITY.md).
- Diagnose-/Run-Logs bleiben lokal bzw. im Upload-ZIP, nie im Repo.

## Teil F – Erste Aufgabe

Siehe [`FIRST_CONTRIBUTION.md`](FIRST_CONTRIBUTION.md) für den vollständigen ersten Durchlauf
(Aufgabe wählen → Branch → PR → Review).
