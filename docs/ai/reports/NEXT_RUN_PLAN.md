# Plan für den nächsten Lauf – SchachTurnierManager

Erstellt: 2026-07-17 · Stand: `development` = `80221fa` · Vorlauf-Bericht:
[`2026-07-17-fabel5-marcel-prs-collaboration-android.md`](2026-07-17-fabel5-marcel-prs-collaboration-android.md)

Dieses Dokument liegt bewusst **im Repository** und nicht nur im Runordner: Ein
paralleler Wartungslauf hat am 2026-07-17 den Runordner unter dem lokalen Temp-Pfad
gelöscht. Load-bearing Handoffs gehören versioniert abgelegt.

## Ausgangslage

| | |
|---|---|
| `development` | `80221fa` |
| Tests | 236/236 grün |
| Offene Contributor-PRs | **#40** (STM-FACH-002, ungeprüft) |
| Push-Gate | gelöst (echte Launcher-Evidence, `core.hooksPath` aktiv) |
| Marcel | `trusted-collaborator`, GitHub-Recht `write` |
| WIP | 2 Ready (#22, #24), 1 In Progress (STM-SEC-001) |

## Vorbedingung für jeden Lauf (nicht überspringen)

Netzzugriff geht auf dieser Workstation **nur** über den internen Unternehmensproxy –
pro Prozess setzen, **niemals committen** (GitSafety blockt ihn zu Recht, das Repo ist
public):

```powershell
$env:HTTPS_PROXY='<interner Proxy>'
$env:HTTP_PROXY='<interner Proxy>'
```

Betrifft `gh`, `git push/fetch`, `npm ci` und Google-Downloads. Ohne ihn: Timeouts –
die im Vorlauf fälschlich als „Skript hängt" gedeutet wurden.

---

## Paket 1 (höchste Priorität) – PR #40 prüfen und adaptieren

**Warum zuerst:** Marcel wartet, und Pairing-Logik entscheidet über echte Turniere. Es ist
das fachlich kritischste Paket im Projekt.

- PR #40, Branch `feature/STM-FACH-002-fide-dutch`, Head `7cfe8ecb`, erstellt 2026-07-17
- Backlog: STM-FACH-002 (P1, Ready, Issue #22)

**Ablauf:**

1. Static-Only-Review (`Invoke-SafePullRequestReview.ps1 -StaticOnly`) – läuft seit
   STM-INFRA-004 auch mit offenem stdin.
2. **Fachprüfung gegen die offizielle FIDE-Primärquelle** C.04.3 (Fassung ab 01.02.2026 –
   Marcel nennt sie im Titel). Fassung real öffnen, nicht aus dem Gedächtnis bewerten.
3. Adoption vom **aktuellen** `development` auf `integration/pr-40-safe-adoption`.
4. Golden-Tests gegen die Spezifikation; gezielt auf stille Regeländerungen achten.
5. Unabhängiger Final-Review mit stärkstem Review-Profil. **Nie automatisch mergen.**
6. `Co-authored-by: Marcel-Mente`, Original-PR wertschätzend kommentieren und als
   *übernommen* schließen.

**Erfahrung aus dem Vorlauf, die hier zählt:** Marcels fachliche Angaben waren jedes Mal
korrekt. Der kritische Fund entstand immer beim Abgleich mit dem *weiterentwickelten*
`development` – z. B. die `IsActive`-Filterung, die seinen TRF-Export Spieler gekostet
hätte. Genau dort hinschauen, nicht bei der Spezifikationstreue.

## Paket 2 – STM-INFRA-006: flakiges Routed-Execution-Gate (P2)

`Test-RoutedExecutionReadiness.ps1` schlägt nichtdeterministisch fehl:
`Cannot find path <runRoot>/checkpoint.json`, in **wechselnden** Szenarien
(`run-budget`, `run-ratelimit`, `run-childerror`). Belegt: 3 lokale Läufe des
unveränderten Skripts = Exit 1/0/1. Hat bereits einen reinen Doku-PR rot gemacht.

**Warum vor Android:** Ein flakiges Pflicht-Gate verleitet dazu, CI-Rot reflexhaft
wegzudrücken. Das untergräbt die Aussagekraft *aller* anderen Gates – auch der
Security-Gates.

Ziel: deterministisches Warten auf den geschriebenen Checkpoint. **Kein** Skip-Schalter,
keine abgeschwächten Assertions. Nachweis: 20 aufeinanderfolgende Läufe grün.

## Paket 3 – STM-MOB-001: Android-APK (Issue #43)

Vollständig spezifiziert in Issue #43. **Braucht einen eigenen Lauf mit vollem Budget.**

**Blocker:** Android SDK fehlt vollständig (kein `adb`, `apksigner`, `gradle`;
`ANDROID_HOME` leer; nur JDK 21.0.11). Kein Gerät angeschlossen.

Reihenfolge:

1. SDK aus offizieller Google-Quelle (`https://dl.google.com/android/repository/…`,
   über Proxy erreichbar – HTTP 200 verifiziert). Per `sdkmanager`: `platform-tools`,
   `build-tools;35.0.0`, `platforms;android-35`. `ANDROID_HOME` **pro Prozess**.
2. Capacitor: nur `@capacitor/core`, `@capacitor/cli`, `@capacitor/android`.
   Keine Firebase/Analytics/Tracking. Lockfile committen.
3. Application-ID `io.github.randspringer90.schachturniermanager`.
4. Keystore außerhalb des Repos bzw. `.secrets/local/`; Passphrase nie ausgeben, nur den
   öffentlichen SHA-256-Fingerprint dokumentieren (`docs/operations/ANDROID_SIGNING.md`).
5. APK bauen, `apksigner verify`, Manifest/Permissions/Tracker/Secrets prüfen.
6. Website-Paket erzeugen – **noch nichts hochladen**.
7. Ohne Gerät: `DEVICE_TEST=MANUAL_PENDING` + manuelle Testanleitung.

**Keine APK-/Keystore-Binärdateien committen.** Danach erst STM-MOB-002 (F-Droid).

## Paket 4 – Continuous Secret Safety Guardian

Eigener Auftrag, im Vorlauf bewusst **nicht** begonnen (Kontextbudget). Verdient einen
eigenen Lauf.

Kern: mehrschichtige, deterministische Secret-Erkennung (PowerShell/Git/Actions, optional
Gitleaks mit fester Version), nicht LLM-abhängig. Bekannter Ausgangspunkt: Der
`history-leftover`-Alarm ist zu grob; der einzige hochkonfidente Treffer ist ein bewusst
synthetischer GitHub-Testwert in `scripts/Test-PullRequestReviewReadiness.ps1`
(Blob `022887e15da2dbbc37994f6d6d5df6f719eb57ea`, markiert als `SECURITY-PATTERN-FILE`).

**Nicht** ganze Sicherheitsdateien pauschal ausschließen – nur eng begrenzte, getestete
Ausnahmen per Pfad + Regel-ID + nicht rückrechenbarem Fingerprint. Ein zusätzlicher
echter Token in derselben Datei muss weiterhin erkannt werden.

## Paket 5 – Owner-Entscheidung: STM-SEC-004 (Engpass)

Unverändert blockiert: **History-Purge vs. Clean-Snapshot**. Braucht eine Owner-Entscheidung
und blockiert STM-REL-004 (RC v1.0.0). Ohne diese Entscheidung gibt es kein v1.0.

## Kleinere offene Pakete

| ID | P | Inhalt |
|---|---|---|
| STM-INFRA-005 | P3 | Hart verdrahtetes lokales Temp-Verzeichnis in 8 Skripten auf `%TEMP%`-Fallback |
| STM-INFRA-007 | P3 | Sanktionierter Branchname für Owner-Pakete ohne Contributor-PR |
| STM-SEC-001 | P1 | In Progress (Rest-Enforcement) |
| STM-SEC-002/003 | P1 | SBOM/Lizenzen, PII |

---

## Regeln, die sich bewährt haben

- **Contributor-PRs nie direkt mergen.** Static-Only-Review → Fachprüfung gegen
  Primärquellen → Adoption vom aktuellen `development` → `Co-authored-by` →
  Original wertschätzend als *übernommen* schließen, nie als abgelehnt.
- **Behauptungen nachstellen, nicht glauben.** Marcels ContentRootPath-Bug wurde so
  bestätigt (`embeddedDashboard` false→true), seine Skript-Zählung so korrigiert (8 statt 9).
- **Owner-PRs brauchen** ein SHA-gebundenes Review `STATIC-EXECUTION-APPROVED:<head-sha>`,
  sonst bricht `ci-static-prerequisite` ab. Nach jedem neuen Commit neu setzen.
- **Merge via `--admin`** (Selbst-Approval ist bei GitHub unmöglich; das Ruleset hat
  RepositoryRole 5 als Bypass-Actor) – **nur** bei vollständig grüner CI.
- **Gates nicht umgehen.** In diesem Lauf haben Branch-Policy und GitSafety je einen
  echten Fehler verhindert (unzulässiger Branchname; interner Hostname im public Repo).

## Nicht wiederholen

- Runordner unter dem lokalen Temp-Pfad können von parallelen Wartungsläufen gelöscht
  werden. Load-bearing Artefakte gehören ins Repo oder unter den kanonischen Log-Root.
- `$input`, `$matches`, `$args` sind automatische PowerShell-Variablen. Der Test
  `PowerShellScripts_DoNotAssignToAutomaticVariables` fängt Neueinführungen jetzt ab.
