# Fabel5-Lauf 2026-07-17 – Marcels PRs, Push-Gate, Kollaborationsmodell, Android

Orchestrator: claude-fable-5 (interaktiv, Owner-Auftrag)
Runordner: `<lokaler Runordner>`

| | |
|---|---|
| **Ausgangs-SHA** | `9adc1117cfef816d8b159dd8ee1c52e3b524f4ec` |
| **End-SHA** | `9cc1d0d` |
| **Tests** | 236/236 grün (dotnet), Frontend Typecheck+Build grün, frischer Clone grün |
| **CI** | alle Owner-PRs vollständig grün (8/8 Checks) |
| **Security** | keine Abschwächung; kein `--no-verify`; keine erfundene Evidence |

## 1. Der Push-Blocker – gelöst mit echter Evidence

Der Lauf startete blockiert: **jeder** Push aus dem Repo scheiterte am
`KFM BAT pre-push gate`.

**Ursache (belegt):** Zentraler Commit `421f6d3` (2026-07-16 21:55, Owner-Freigabe) nahm
STM in das Fleet-Gate auf; `core.hooksPath` wurde 21:56:59 gesetzt. Die Evidence der drei
STM-Launcher stand seit `e8f4d1e`/`24d6c3f` auf `pending` mit leerem
`testedVersionSha256` – sie war nie erfasst worden. Nicht verursacht durch diesen Lauf.

**Lösung gemäß Owner-Entscheidung:** PR #33 zuerst adaptiert, dann **echte** funktionale
Evidence erzeugt.

| Launcher | testVersionSha256 | Evidence |
|---|---|---|
| `RUN_TURNIERMANAGER.bat` | `13AF81F5…9861E` | user + noninteractive + logging |
| `scripts/Start-Desktop.bat` | `647163B9…6A4FF` | user + noninteractive + logging |
| `scripts/Start-Portable.bat` | `ECFECA3D…79D802` | user + noninteractive + logging |

Alle drei Launcher wurden **real ausgeführt** (Health 200, `embeddedDashboard: true`,
Logdateien nachgewiesen) und über den kanonischen Recorder
`Update-KFMBatchRegistryRepo.ps1` versionsgebunden eingetragen.

**Gate danach:** `user=3 noninteractive=3 logging=3 safeFunctional=3 exit=0`

`core.hooksPath` blieb aktiv, `--no-verify` wurde nie verwendet, keine temporäre
Ausnahme war nötig. Die Evidence-Logs liegen außerhalb des Repositories
(`<lokaler Log-Root>/SchachTurnierManager/bat-evidence/<timestamp>`) und enthalten keine
Secrets und keine personenbezogenen Daten.

### Korrektur einer Annahme im Auftrag

Der Auftrag ging davon aus, PR #33 bearbeite „genau die Launcher, deren Evidence fehlt".
Das stimmt so nicht: **PR #33 fasst die drei `.bat`-Dateien textuell nicht an** – nur
`Program.cs`, `New-RunLogBundle.ps1` und zwei Doku-Dateien. Geprüft wurde deshalb auch,
ob die Evidence nach dem Merge stale würde: Nein – die Versions-Hashes umfassen nur den
`.bat`-Closure (`.bat` + referenzierte `.ps1`), `Program.cs` (C#) liegt nicht darin.

Die Owner-Reihenfolge war dennoch richtig, aber aus einem anderen Grund: Der
ContentRootPath-Fix ändert das **Verhalten** der Launcher. Evidence davor hätte
funktionierendes Verhalten bescheinigt, das es ohne den Fix nicht gab.

## 2. Marcels Pull Requests – alle drei integriert

| Owner-PR | Backlog | Original | Merge | Original-PR |
|---|---|---|---|---|
| #34 | STM-REL-001 | #33 | `b263925` | COMMENTED_AND_INTEGRATED |
| #35 | STM-IE-001 | #30 | `6a2d021` | COMMENTED_AND_INTEGRATED |
| #36 | STM-DOC-001 | #31 | `aad29e1` | COMMENTED_AND_INTEGRATED |

Alle drei wurden **nicht** direkt gemergt, sondern vom aktuellen `development` adaptiert.
Attribution durchgehend über `Co-authored-by: Marcel-Mente`. Kein Original-PR wurde als
abgelehnt geschlossen.

### PR #33 – Bugreport unabhängig reproduziert

Marcels ContentRootPath-Befund wurde nicht geglaubt, sondern nachgestellt: Vorher-Stand
aus `origin/development` in separatem Worktree gebaut, `wwwroot` daneben gelegt, aus
**fremdem** Arbeitsverzeichnis gestartet.

| Stand | `wwwroot` neben EXE | CWD | `/api/health` → `embeddedDashboard` |
|---|---|---|---|
| `development` 9adc111 (ohne Fix) | ja | fremd | **`false`** ← Bug reproduziert |
| mit Fix | ja | fremd | **`true`** ← behoben |

Marcels Folgebefund („9 weitere Skripte mit hart verdrahtetem `<lokales Temp>`") wurde
nachgezählt und korrigiert: Es sind **8** – 6 mit Parameter-Default plus
`New-ContributorTaskPrompt.ps1` und `Test-ContributorKickoffReadiness.ps1`. Erfasst als
STM-INFRA-005.

### PR #30 – kritischer Fachfix bei der Adoption

Marcels TRF16-Feldpositionen wurden gegen die **offizielle FIDE-Spezifikation** (C.04
Annex 2, PDF real gelesen) geprüft: durchgehend korrekt.

Der wichtigste Fund bei der Anpassung an den heutigen Stand:
`StandingsCalculator.Calculate` filtert seit STM-FACH-001 auf `IsActive`. Marcels Export
hätte dadurch **zurückgezogene Spieler aus dem FIDE-Bericht verloren**. Gelöst über
`Calculate(tournament, includeInactive: true)`, den nur der TRF-Pfad nutzt.

Weiter angepasst: Zeilenenden auf **CR** (Remark 1 der Spezifikation; Marcel hatte LF
gewählt), Line-Builder wirft bei Feldüberlängen statt Spalten zu verschieben,
FIDE-ID-Härtung, Steuerzeichen-Sanitisierung. Tests von 3 auf **13 Golden-Tests**
aufgestockt.

**Basis-Drift:** Der geprüfte Commit `8a49556` lag auf `9adc111`. Nach dem Merge von #34
wurde er per Cherry-pick auf den neuen Stand übertragen (`ce72395`); der ursprüngliche
Commit bleibt als `archive/pr-30-adoption-base-9adc111` erhalten. Verifiziert, dass
**beide** Beiträge koexistieren (ContentRootPath-Fix **und** TRF16-Endpoint).

### PR #31 – Versionsangaben verifiziert

Marcels Angaben wurden gegen die kanonischen Dateien geprüft und waren **alle exakt**:
`global.json` = 10.0.300 + `rollForward: latestFeature`; Vite 8.0.16 `engines` =
`^20.19.0 || >=22.12.0`; Node 24 lauffähig (selbst gebaut).

Angepasst: Die Tabelle verweist jetzt auf die kanonischen Quellen statt auf eine feste
Vite-Major-Version, damit sie beim nächsten Upgrade nicht veraltet.

Verifiziert über frischen Clone (`git clone` → `git switch development` →
`dotnet build` → `dotnet test`, 235/235 grün), Linkcheck (8/8), Skriptreferenzen (4/4),
`Test-CollaborationReadiness.ps1` = OK.

## 3. Marcel als Trusted Co-Developer (#42, `e57c7dc`)

Neue Rolle **`trusted-collaborator`** (@Marcel-Mente).

**Erweiterte Bereiche, unveränderte Rechte.** GitHub-Recht bleibt bewusst `write` –
verifiziert, dass die tatsächlichen Rechte der Policy entsprechen
(`Randspringer90: admin`, `Marcel-Mente: write`). Keine GitHub-Einstellung musste
geändert werden.

Kern ist `config/collaboration-policy.json` (+ Schema). Entscheidend:
`Test-CollaborationReadiness.ps1` **koppelt die Policy an die Realität** statt sie nur zu
validieren – jeder als geschützt deklarierte Pfad muss in CODEOWNERS gedeckt sein, die
Nightly-Ausschlüsse müssen zu `config/nightly-execution.json` passen, die Rechtegrenze
`write` wird per `const` erzwungen. Der Alias `friend` bleibt gültig, damit bestehende
Parser nicht brechen.

CODEOWNERS ergänzt um Android-Signing-Konfiguration, `docs/distribution/**` und das
Kollaborationsmodell selbst.

## 4. Marcels Feature-Queue (`9cc1d0d`)

28 neue Backlog-Aufgaben: Mobile (STM-MOB-001..009), Schach/Turnierlogik
(STM-FACH-004..010), Import/Export (STM-IE-005..008), UX/Qualität (STM-UX-005..012).
Vorher gegen bestehende IDs dedupliziert.

**WIP-Regel eingehalten:** 2 Ready, 1 In Progress. Alle neuen Aufgaben stehen bewusst auf
Backlog oder Blocked mit benannter Abhängigkeit.

Marcel zugewiesen sind nur die **tatsächlich startbaren** Issues: #22 (STM-FACH-002) und
#24 (STM-IE-002, durch STM-IE-001 entsperrt).

## 5. Android – bewusst nicht begonnen

`ANDROID_APK=NICHT_GEBAUT`, `DEVICE_TEST=MANUAL_PENDING`.

**Befund:** Auf der Workstation fehlt der Android SDK vollständig – kein `adb`, kein
`apksigner`, kein `gradle`, `ANDROID_HOME` leer. Nur JDK 21.0.11 ist vorhanden. Kein
Gerät angeschlossen.

Eine echte APK erfordert damit zuerst einen mehrere GB großen SDK-Download über den
Proxy, dann Capacitor, Gradle, Keystore und Signierung. Das Paket wurde nach der Regel
„kein Paket beginnen, das nicht vollständig abschließbar ist" **nicht angefangen** –
ein halb konfiguriertes Android-Projekt wäre schlechter als ein sauberer Handoff.

Stattdessen vollständig spezifiziert als **Issue #43 (STM-MOB-001)** mit Architektur,
Application-ID, Flavors, Permissions, Signing-Regeln, Testmatrix und DoD.
Bestandsaufnahme: `05-android/toolchain-assessment.md` im Runordner.

## 6. Eigenes Owner-Paket: STM-INFRA-004 (#39, `4681e01`)

`Invoke-SafePullRequestReview.ps1` wies der automatischen PowerShell-Variablen `$input`
(Pipeline-/stdin-Enumerator) einen Wert zu und blockierte dadurch bei offenem stdin
unbegrenzt. Das erklärt rückwirkend die im Vorlauf als „Netz-/Proxy-Problem"
fehlgedeuteten Hänger.

**Messbar:** `Test-PullRequestReviewReadiness.ps1` mit offenem stdin – vorher Hänger
> 12 min, jetzt **EXIT=0 nach 17 s**; 42/42 synthetische Risikofälle bestehen unverändert.

Der neue Test `PowerShellScripts_DoNotAssignToAutomaticVariables` deckt die **ganze
Fehlerklasse** ab und hat dabei zwei weitere echte Fundstellen in
`Import-TournamentPreset.ps1` aufgedeckt (`$matches`, `$args`) – beide mitbehoben, statt
den Test abzuschwächen.

## 7. Neue Befunde

| ID | P | Befund |
|---|---|---|
| **STM-INFRA-005** | P3 | Hart verdrahtetes `<lokales Temp>` in 8 weiteren Skripten (Marcels Folgebefund, nachgezählt) |
| **STM-INFRA-006** | P2 | `Test-RoutedExecutionReadiness.ps1` ist **flaky**: 3 lokale Läufe des unveränderten Skripts = Exit 1/0/1, jedes Mal ein anderes Szenario, immer eine `checkpoint.json`-Race. Hat einen reinen Doku-PR rot gemacht. Ein flakiges Pflicht-Gate verleitet dazu, CI-Rot reflexhaft wegzudrücken. |
| **STM-INFRA-007** | P3 | Branchnamen-Policy hat keinen sanktionierten Pfad für Owner-Pakete ohne Contributor-PR. `ci.yml` verlangt bei Review ≠ `SAFE_FOR_ISOLATED_BUILD` zwingend `integration/pr-<nr>-safe-adoption`; die bisherige Praxis setzt die Issue-Nummer ein und behauptet damit eine Adoption, die es nicht gibt. |

## 8. Umgebungsbefunde

- **Proxy zwingend:** GitHub, `gh`, `git push/fetch`, `npm ci` und Google-Downloads
  funktionieren nur über `<interner Unternehmensproxy>` (pro Prozess, nie committet).
  Ohne ihn: Timeouts.
- **Merges brauchten `--admin`:** Ruleset `collab-development` verlangt 1 Approval +
  Code-Owner-Review; GitHub verbietet Selbst-Approval. Das Ruleset hat
  `RepositoryRole 5` (Admin) als Bypass-Actor mit `mode=always` – der vorgesehene Weg.
  Alle 7 Pflicht-Checks waren jedes Mal grün.
- **Datenverlust im Runordner:** Ein paralleler `KFM_Projektinventur`-Lauf (13:32) hat
  `<lokaler Runordner>` gelöscht. Betroffen waren nur Berichts-Kopien
  bereits gemergter Pakete. Die **kritische Launcher-Evidence liegt in `<lokaler Log-Root>`** und
  blieb intakt; die Registry steht weiterhin auf `passed`.

## 9. Release-Reife

- Backlog: 15 von 59 Aufgaben Done.
- Offene P0/P1: STM-SEC-004 (Owner-Entscheidung History), STM-REL-004 (abhängig),
  STM-SEC-001 (In Progress), SEC-002/003, FACH-002 (Marcel, Ready), REL-002/003.
- Kritischer Pfad zu v1.0: FACH-002 → FACH-003 (Marcel) ∥ SEC-001/002/003 → SEC-004
  (**Owner-Entscheidung, Engpass**) → REL-002/003 → REL-004.

## 10. Nächster Prompt

`<lokaler Runordner>\final\NEXT_PROMPT.md`
