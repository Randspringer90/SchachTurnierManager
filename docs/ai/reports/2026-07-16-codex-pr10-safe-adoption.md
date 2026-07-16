# STM-FACH-001: sichere Adoption von Marcel-Mentes PR #10

## Ergebnis

Marcels fachlicher Fund und die tragfähigen Testideen aus PR #10 wurden nicht
blind übernommen, sondern auf Basis von `development` (`e6ac402`) neu integriert.
Die Umsetzung führt einen opt-in FIDE-Modus für ungespielte Runden ein, bewahrt
das Defaultverhalten und behebt zugleich den von Marcel gefundenen Withdrawal-
Fehler. Der Contributor wird im Integrationscommit als Co-Autor gewürdigt.

## Herkunft und sichere Prüfung

- Original-PR: #10, `STM-FACH-001: Freilos-/Forfeit-Tiebreak-Wertung verdrahten`
- Contributor: `Marcel-Mente`
- geprüfter Original-Head: `ede5390a8f49ff01ee1dbd8ca081f666af434379`
- Integrationsbasis: `e6ac40266d13fe01eb17bc9d3600dc6a77a5e1c4`
- Integrationsbranch: `integration/pr-10-safe-adoption`
- keine Ausführung von Fremdcode vor der statischen Freigabe
- keine neuen Dependencies, Binärdateien, Archive, Symlinks oder Installer-/Build-
  Manipulationen
- keine erkannten Secrets, personenbezogenen Echtdaten oder lokalen Owner-Pfade
- der PR-Dependency-Delta-Check blieb absichtlich auf `OWNER_REVIEW_REQUIRED`;
  die Owner-Adaption wurde anschließend aus der aktuellen Basis implementiert

## Fachentscheidung

Maßgeblich ist die FIDE-Handbook-Regel C.07 in der seit 1. März 2026 gültigen
Fassung, insbesondere Art. 15 und 16:

- offizielle Quelle: <https://handbook.fide.com/chapter/TieBreakRegulations032026>
- Abrufdatum: 2026-07-16
- Art. 16.3 passt den Stand eines Teilnehmers ausschließlich für die Wertung
  seiner Gegner an;
- Art. 16.4 verwendet für die eigene Wertung einen Dummy und deckelt ihn je nach
  Kategorie durch den angepassten Stand des vorgesehenen Gegners oder durch
  Remispunkte mal Rundenzahl;
- Art. 16.5 gibt VUR-Beiträgen beim Streichen niedrigster Werte Vorrang.

Der Modus gilt nur für Schweizer Buchholz, Cut-1, Cut-2 und Median. Sonneborn-
Berger, Direktvergleich und Performance wurden entsprechend dem bestätigten Scope
nicht verändert. Das Datenmodell unterscheidet derzeit keine angeforderten Halb-
und Nullpunkt-Byes; solche Kategorien werden daher nicht implizit erfunden.

## Übernommen und angepasst

Übernommen wurden Marcels Kernideen:

- expliziter Modus für die Buchholz-Behandlung ungespielter Runden;
- spielerspezifische Betrachtung von Bye und Forfeit;
- Regression gegen den Verlust historisch erspielter Punkte nach Withdrawal;
- gezielte Buchholz-/Forfeit-Tests.

An den aktuellen Stand und die bestätigten Regeln angepasst wurden:

- Default `IgnoreUnplayedRounds` für alte Turniere und bestehende Baselines;
- `FideVirtualOpponent` ausschließlich für Schweizer Turniere;
- offene `NotPlayed`-Partien und fehlende Pairings in offenen Runden bleiben ohne
  Dummy; erst endgültige Runden werden berücksichtigt;
- `ForfeitTiebreakPolicy` hat dokumentierten Vorrang: realer Gegner oder Dummy,
  niemals beides;
- Art.-16.3-Anpassung, Art.-16.4-Caps und Art.-16.5-VUR-Streicher;
- eine kanonische Scoreliste für Buchholz, Cut-1, Cut-2 und Median;
- vollständiger Transport durch Domain, Application, API, UI, JSON/SQLite,
  Backup/Restore, Export und Audit;
- unbekannte oder in Altdaten fehlende Enumwerte fallen auf den Legacy-Default
  zurück.

## Withdrawal-Fix

Historische Ergebnisse werden jetzt für alle im Turnier vorhandenen Spieler
berechnet. Erst die fertige sichtbare Rangliste wird auf aktive Spieler begrenzt.
Damit behalten aktive Spieler Punkte und gegnerbasierte Beiträge aus bereits
gespielten Partien, während pausierte oder zurückgezogene Spieler verborgen und
durch die bereits vorhandene Active-Filterung nicht neu gepaart werden.

## Verifikation vor dem Integrationscommit

- `dotnet build SchachTurnierManager.sln -c Release --no-restore`: grün
- `dotnet test SchachTurnierManager.sln -c Release --no-restore`: 220/220 grün
  (Golden 3, Application 99, Infrastructure 18, Domain 100)
- Frontend-Typecheck und Vite-Build über den sicheren npm-Wrapper: grün
- PR-Review-Readiness: grün
- Agent-Skill-Readiness: grün
- Agent-Instruction-Integrity: grün
- Knowledge-Persistence-Safety: grün
- Prompt-Injection-Defense: grün
- Git-Commit-Safety: grün
- Repository-Open-Source-Safety: grün
- Collaboration-Readiness: grün
- `git diff --check`: grün

Das vollständige ReleaseGate einschließlich Portable-Paketierung ist grün. Der Commit
erfolgt ausschließlich über `scripts/Commit-If-Green.ps1`. GitHub-Checks,
SHA-gebundene Owner-Freigabe, unabhängiger Final-Review und Remote-Kollisionscheck
folgen im Owner-Integrations-PR.

## Attribution

Der Integrationscommit enthält:

`Co-authored-by: Marcel-Mente <304076111+Marcel-Mente@users.noreply.github.com>`
