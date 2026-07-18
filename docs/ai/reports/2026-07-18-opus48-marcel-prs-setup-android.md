# Opus-4.8-Lauf 2026-07-18 – Marcels PRs, Setup-EXE, Android-APK

Orchestrator: claude-opus-4-8 (interaktiv, gründliches Owner-Review)

| | |
|---|---|
| **Ausgangs-SHA** | `7ed371e4b0a174a06775b8d4905af35e944047dd` |
| **End-SHA** | `a0b56b428c985c8e82348ec464a154588f5d2f02` |
| **Tests** | 513/513 grün (dotnet), Frontend grün, frischer Android-Build grün |
| **CI** | alle gemergten Owner-PRs vollständig grün |

## 1. Marcels Pull Requests – beide integriert

| Owner-PR | Backlog | Original | Merge | Original-PR |
|---|---|---|---|---|
| #45 | STM-FACH-002 | #40 | `7634399` | COMMENTED_AND_INTEGRATED |
| #48 | STM-IE-002 | #44 | `8f6ce32` | COMMENTED_AND_INTEGRATED |

### PR #40 – FIDE-Dutch-Schweizer-System (fachlich kritischstes Paket)

**FIDE C.04.3 unabhängig gegen die Primärquelle geprüft** (`handbook.fide.com/chapter/C0403202602`,
Fassung ab 01.02.2026): Artikelstruktur 1–5, Kriterien [C1]–[C21], kein PSD mehr, Farbzuteilung
Art. 5.2.1–5.2.5 – alles bestätigt. Marcels Referenzdoku ist korrekt, inkl. der Warnung vor der
veralteten 2017er-Fassung.

Geprüft und bestätigt: Optimal-V2 bleibt Default (`SelectSwissStrategy` fällt auf `_swiss` zurück,
keine stille Änderung bestehender Turniere); Determinismus (kein `Random`/`Guid.NewGuid`/`DateTime`);
Sortierung nach Art. 1.2; `SwissInitialColour` ist Eingabe, die Engine würfelt nicht; die
Golden-Erwartungen sind von Hand aus dem Regeltext hergeleitet (kein Zirkelschluss) und gegen
bbpPairings 6.0.0 gegengeprüft, korrekt als spec-Maßstab (C.04.2 Art. 1.4) eingeordnet.

Adoptions-Anpassung: Marcels Handoff referenzierte `STM-FACH-004`, das auf development bereits für
Mannschaftsturniere vergeben war → auf STM-FACH-011 korrigiert; die offene UI-Auswahl als
STM-FACH-012 erfasst.

### PR #44 – Swiss-Manager-/TRF16-Import

Neue Dependency `System.Text.Encoding.CodePages` 10.0.0 im Owner-Review geprüft: Microsoft-First-Party
(MIT), zwingend für Windows-1252 unter .NET 10 → genehmigt. Import über `byte[]` (kein Pfad-Traversal),
`ReplaceExisting` explizit, Encoding-Erkennung defensiv (strikter UTF-8 zuerst, dann 1252-Fallback).

Adoptions-Besonderheit: PR #44 entstand vor dem FIDE-Dutch-Merge und berührt dieselben Dateien
(`TournamentService.cs`, `Program.cs`). Übernahme daher per **3-way-Apply** – verifiziert, dass beide
Beiträge koexistieren.

Nebenbefund (kein Regress): Der CSV-Export neutralisiert keine CSV-Formel-Injection – dasselbe
projektweite Muster wie im bereits gemergten STM-IE-001-Export. Als STM-SEC-006 (projektweit) erfasst.

## 2. STM-INFRA-006 – flakiges Gate an der Wurzel behoben (#47, `6ee8fcd`)

Das `agent-integrity`-Gate blockierte die Integration. **Ursachenanalyse ging tiefer als die
Oberfläche:** Das Symptom war „checkpoint.json fehlt", die eigentliche Ursache ein
**nichtdeterministischer Graph-Hash** – `Get-TaskGraphHash` serialisierte per `ConvertTo-Json`, dessen
Property-Reihenfolge bei Hashtables zwischen Prozessen variiert (randomisierter Hash-Seed). Derselbe
Graph ergab so verschiedene Hashes; der Kindprozess brach mit „Manipulation" ab und schrieb den
Checkpoint gar nicht. Das hätte auch einen echten Resume fälschlich blockiert.

Fix: JSON-Roundtrip-Normalisierung + kanonische Serialisierung mit rekursiv sortierten Schlüsseln,
plus Move-Retry und deterministisches Warten. **20/20 Läufe grün** (vorher 9/20 Fehlschläge). Keine
Assertion abgeschwächt, kein Skip-Schalter.

Ein erster, oberflächlicher Fix-Versuch (nur Warten auf die Datei) schlug fehl (9/20) und führte zur
korrekten tieferen Diagnose – dokumentiert als ehrlicher Verlauf.

## 3. Setup-EXE – gebaut, verifiziert, lokal bereitgestellt

Frisch vom aktuellen development gebaut (nicht die veraltete EXE): `SchachTurnierManager_Setup_0.54.1.exe`
(36,73 MB). Inno Setup 6.7.3 dafür per-user (keine Adminrechte) installiert. **Isolierter Smoke-Test
bestanden:** Install in Temp-Verzeichnis (Exit 0, alle App-Dateien inkl. `wwwroot`), Deinstall (Exit 0),
**reale Turnierdaten unter %LocalAppData% unberührt** (6/6 Dateien). SmartScreen erwartbar (nicht
produktiv signiert). EXE liegt lokal unter `output\installer\`, **nicht** committet. Der finale manuelle
Test bleibt beim Owner.

## 4. Android-APK – Toolchain + signierte APK gebaut, Merge blockiert

Der Hauptblocker des Vorlaufs (fehlender Android SDK) ist beseitigt: JDK 21 + Android SDK
(cmdline-tools, platform-tools, build-tools;35.0.0, platforms;android-35) lokal eingerichtet (nicht im
Repo).

Capacitor-Companion-App (Application-ID `io.github.randspringer90.schachturniermanager`, nur erlaubte
Pakete 7.4.3 exakt gepinnt, keine Tracker). Companion-Launcher mit konfigurierbarer Serveradresse (keine
feste IP), Verbindungstest mit Timeout, sicherer lokaler Speicherung, Versionsanzeige. Nur
`INTERNET`-Permission. Test-Flavor mit dokumentierter Network-Security-Config (Cleartext nur im LAN).

**Debug-APK und signierte Test-Release-APK gebaut, `apksigner verify` bestanden (v1+v2+v3).** APK-Inhalt
verifiziert: keine Secrets, keine Tracker, keine feste IP. Keystore außerhalb des Repos
(`.secrets/local/`, gitignored), Passwort DPAPI-geschützt, nur öffentlicher Fingerprint dokumentiert
(`docs/operations/ANDROID_SIGNING.md`). Kein APK-/Keystore-Binärartefakt im Repo.

`DEVICE_TEST=MANUAL_PENDING` – kein Galaxy S25 angeschlossen; vollständige Geräte-Anleitung erstellt.

**Merge-Blocker (STM-INFRA-008, Owner-Entscheidung nötig):** Der textbasierte PR-Security-Review kann die
für Capacitor zwingenden Binärdateien nicht verifizieren (`gradle-wrapper.jar` → `BLOCKED_ARCHIVE`,
Icon-/Splash-PNGs → `INCOMPLETE_PATCH`) und liefert `BLOCKED_UNVERIFIED`; das Gate wirft hart,
unabhängig von der Owner-Freigabe. Zusätzlich erzeugt die branch-übergreifende BAT-Fleet-Registry
`STALE_REGISTRATION` für `gradlew.bat`. Beide Gates sind nicht für Android-Projekte ausgelegt. Ein
Bypass würde die Binär-Prüfung generell aushebeln – **bewusst nicht gemacht**. PR #49 bleibt offen; die
APK ist geliefert.

## 5. Neue Backlog-Einträge

| ID | P | Inhalt |
|---|---|---|
| STM-FACH-011 | P2 | Setzlisten-Vergabe nach C.04.2 Art. 2.2 (Folge aus FIDE-Dutch) |
| STM-FACH-012 | P2 | WebApp-UI-Auswahl für Pairing-Strategie/Anfangsfarbe |
| STM-SEC-006 | P2 | CSV-Formel-Injection projektweit neutralisieren |
| STM-INFRA-008 | P2 | PR-Security-Gate für Android-/Binär-Buildartefakte tragfähig machen |

## 6. Umgebungsbefunde

- Merges via `--admin` (Ruleset-Bypass-Actor), nur bei vollständig grüner CI; Selbst-Approval ist bei
  GitHub unmöglich.
- Der interne Proxy ist für jeden Netzzugriff nötig (pro Prozess, nie committet).
- GitSafety hat zwei eigene Fehler verhindert (Ortsbezug im Keystore-Dname, redigiert).

## 7. Nächster Prompt

Priorität: STM-INFRA-008 (Android-Merge entsperren) → PR #49 mergen → Galaxy-S25-Gerätetest →
STM-FACH-012 (UI) → STM-FACH-003 (große Felder) → STM-SEC-004 (Owner-Entscheidung, v1.0-Engpass).
