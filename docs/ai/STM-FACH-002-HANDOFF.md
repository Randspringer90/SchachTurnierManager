# STM-FACH-002 – Handoff / Zwischenstand

**Stand:** 2026-07-16 · **Branch:** `feature/STM-FACH-002-fide-dutch` (6 Commits, **nur lokal**,
bewusst noch nicht gepusht) · **Issue:** [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22)

**Fortschritt: ~55 %.** Tests und Regelgrundlage stehen vollständig. Von der Implementierung sind
Profil-Schicht und Farbzuteilung fertig (grün); es fehlt das **Paarungsverfahren** selbst —
Art. 3/4 und die Kriterien [C5]–[C21].

---

## Wenn du nur drei Minuten hast

1. **Regelgrundlage ist `docs/FIDE_DUTCH_REFERENCE.md`.** Dort stehen alle Artikelnummern mit Quelle
   und Abrufdatum. Lies zuerst die drei Warnkästen – sie sind teuer erkauft.
2. **C.04.3 wurde zum 01.02.2026 NEU GEFASST.** Die 2017er Struktur (A–E, C.5–C.19, PSD) gilt nicht
   mehr. Wer aus dem Gedächtnis oder von `spp.fide.com` arbeitet, baut das falsche Regelwerk.
3. **Die Golden-Tests sind bereits gegen eine Referenz-Engine verifiziert.** Wenn ein Test rot ist,
   liegt der Fehler mit hoher Wahrscheinlichkeit in *deiner Implementierung*, nicht im Test.

---

## Was fertig ist

| | |
|---|---|
| Regelreferenz mit Artikelnummern | `docs/FIDE_DUTCH_REFERENCE.md` |
| Strategie-Interface, V2 unverändert dahinter und weiterhin Default | `ISwissPairingStrategy`, Commit `304aa8a` |
| Settings: `PairingStrategy`, `SwissInitialColour` | `TournamentSettings` |
| Golden-Turnier A (8 Spieler) | 5/5 Runden hergeleitet **und** gegengeprüft |
| Golden-Turnier B (7 Spieler, Freilose) | 5/5 Runden hergeleitet **und** gegengeprüft |
| Golden-Turnier C (8 Spieler, kampflos) | 5/5 Runden hergeleitet **und** gegengeprüft |
| Property-Tests der absoluten Kriterien | 9 Feldgrößen × 5 Verläufe × 6 Zusagen |
| **Profil-Schicht (grün)** | `FideDutchPlayerProfile`, `FideDutchProfileBuilder` + 10 Tests |
| **Farbzuteilung Art. 5 (grün)** | `FideDutchColourAllocator` + 26 Tests |

**Testlage:** 220 bestehende Tests grün, 36 neue Bausteintests grün, 286 Golden-/Property-Tests
**absichtlich rot** (`FideDutchPairingStrategy` ist noch ein Stub, der `NotImplementedException` wirft).

### Die Profil-Schicht ist fertig und verifiziert

`FideDutchProfileBuilder` liefert je Spieler: Punkte, TPN, Farbfolge (ohne ungespielte Runden),
tatsächlich gespielte Gegner, Freilos-Sperre und Float-Historie (Vorrunde + zwei Runden zurück).
Die Präferenz-Einstufung nach Art. 1.7 sitzt in `FideDutchPlayerProfile.Preference` — **mit beiden
Auslösern von Art. 1.7.1**.

Die Erwartungswerte der Tests stammen aus den Checklisten von bbpPairings, nicht aus eigener
Anschauung. `FideDutchProfileBuilderTests` konstruiert die Rundenverläufe direkt und braucht die
Paarungsstrategie **nicht** — die Schicht ist unabhängig prüfbar. Wer weiterbaut, kann sich auf diese
Zahlen verlassen.

### Die Farbzuteilung ist fertig und verifiziert

`FideDutchColourAllocator.Allocate(a, b, initialColour)` setzt Art. 5.2 vollständig um und liefert
neben den Farben auch Fundstelle und Klartextbegründung für den Audit-Trail. Sie ist total (Stufe
5.2.5 greift immer) und unabhängig von der Aufrufreihenfolge. **Art. 5 ist damit erledigt** – wer
weiterbaut, muss sich um Farben nicht mehr kümmern, nur noch um die Frage, WER gegen WEN spielt.

## Was fehlt

1. **Das Paarungsverfahren** — Art. 3 (Brackets, S1/S2, Limbo, Kandidat, Remainder), Art. 4
   (BSN, Transpositionen, Exchanges, MDP-Mengen), Kriterien [C5]–[C21].
   Das ist der große Rest, ca. 35–40 % der Gesamtaufgabe. Profile und Farbzuteilung stehen als
   Bausteine bereit; `FideDutchPairingStrategy.GenerateNextRound` muss sie nur noch verdrahten.
2. Audit-Trail pro Bracket-Entscheidung; Setzlisten-Warnung (siehe unten).
3. `CHANGELOG.md`, `docs/AUDIT_JOURNAL.md`, Push, PR nach **`development`** (nicht `main`!).
4. Issue-Kommentar zu den veralteten Artikelnummern; Folge-Ticket Setzliste.

---

## Die drei Fallen (alle real hineingetappt)

### 1. „Absolut" hat ZWEI Auslöser, verknüpft mit ODER (Art. 1.7.1)

Nicht nur Farbdifferenz > ±1, **sondern auch** dieselbe Farbe in den beiden letzten **gespielten**
Runden. Ein Spieler mit Differenz −1 kann absolut sein (`WBB`), einer mit Differenz 0 ebenfalls
(`WWBB`). Beides prüfen, absolut gewinnt. Das entscheidet über **[C3]** und damit darüber, welche
Paarungen überhaupt erlaubt sind. → Golden-Turnier B, Runde 4.

### 2. [C13] ist nicht redundant zu [C12]

[C12] zählt jede unerfüllte Farbpräferenz gleich, [C13] nur die **starken**. Zwei Kandidaten mit
identischem [C12] unterscheiden sich bei [C13] – und dann entscheidet es, auch gegen die
Transpositionsreihenfolge aus Art. 4.2. → Golden-Turnier B R4 und C R4.

### 3. [C18]–[C21] sind keine Feinjustierung

Sie sind die „kein doppelter Absteiger"-Regeln und entscheiden ganze Runden, wenn alles bis [C17]
gleichsteht. Die alte Fassung sagt es klarer: *„minimize the score differences of players who
receive the same downfloat as two rounds before"*. → Golden-Turnier A, Runde 5.

**Muster:** Alle drei Fehlschläge lagen in Regeln, die beim Lesen wie Feinschliff aussehen. Eine
Implementierung, die bei [C13] oder [C17] aufhört, wird bei Turnier A grün und paart trotzdem falsch.

---

## Die Gegenprobe (wichtigstes Werkzeug)

**C.04.2 Art. 1.4 verlangt, dass zugelassene Programme zu identischen Paarungen kommen.** Der
Abgleich gegen eine Referenz-Engine ist damit nicht bloß eine zweite Meinung, sondern der von der
Regel selbst definierte Maßstab. Ohne ihn wären zwei falsche Golden-Tests entstanden – grün und
falsch, die schlimmste Kombination.

**Werkzeug liegt in `tmp/`** (gitignored, also nach einem frischen Clone neu zu beschaffen):

```powershell
cd tmp
pwsh -File .\build-trf.ps1 -Tournament A -Rounds 2 -Out a-r3.trf
.\bbpPairings-v6.0.0\bbpPairings.exe --dutch a-r3.trf -p out.txt -l check.txt
```

- `build-trf.ps1` kennt alle drei Turniere und ihre bestätigten Verläufe. `-Rounds N` = wie viele
  gespielte Runden in die Datei sollen; ausgelost wird dann Runde N+1.
- `-l check.txt` erzeugt eine **Checkliste** mit Punkten, Farbhistorie, Präferenz, [C2]-Sperre und
  Float-Historie je Spieler. Sie ist zum Debuggen wertvoller als die Paarung selbst.
  Lesart der Präferenzspalte: `B` = absolut, `(B)` = stark, `b` = mild, `A` = keine.

**Engine:** bbpPairings 6.0.0, Apache-2.0, erschienen **01.02.2026** (= Inkrafttreten der neuen
Fassung), <https://github.com/BieremaBoyzProgramming/bbpPairings/releases/tag/v6.0.0>,
Datei `bbpPairings-v6.0.0-x86_64-pc-windows.zip`. Nur diese Version verwenden – eine ältere prüft
gegen abgelaufenes Regelwerk und würde Fehler *bestätigen*.

**Nicht als unabhängige Gegenprobe geeignet:** Swiss-Manager und Vega nutzen beide **JaVaFo** als
Engine. Es gibt praktisch nur zwei unabhängige Implementierungen: JaVaFo (braucht Java, hier nicht
installiert) und bbpPairings.

**TRF-Format:** Spalten sind gegen `test/tests/dutch_2025_C5.input` aus dem bbpPairings-Repo
verifiziert. Zwei Stolpersteine, die schon Zeit gekostet haben: Punkte müssen mit **InvariantCulture**
formatiert werden (deutsches Gebietsschema schreibt sonst `1,0` statt `1.0`), und das Gegnerfeld beim
Freilos ist literal **`0000`**, nicht rechtsbündig `   0`.

---

## Architekturentscheidungen (mit Marcel abgestimmt)

- **FIDE-Dutch als eigene Strategie** neben der V2-Engine, nicht als Erweiterung. Die Verfahren sind
  grundverschieden (V2 minimiert global eine Gesamtstrafe, Dutch arbeitet eine vorgeschriebene
  Reihenfolge ab) und lassen sich nicht ineinander überführen.
- **V2 bleibt Default.** FIDE-Dutch wird über `TournamentSettings.PairingStrategy` bewusst gewählt.
- **Anfangsfarbe ist Eingabe, kein Zufall.** Art. 5.1 verlangt einen Losentscheid vor Runde 1 – den
  trifft der Turnierleiter, die Engine würfelt nie selbst (sonst Widerspruch zu C.04.2 Art. 1.4).
  → `TournamentSettings.SwissInitialColour`, Standard Weiß.
- **Ein PR**, aber in nachvollziehbaren Schritten committet.

## Bekannte Abweichung: Setzliste

`TournamentService.NormalizePlayerForSave` vergibt Startränge als **Eingabereihenfolge**
(`tournament.Players.Count + 1`), nicht nach Spielstärke – Widerspruch zu C.04.2 Art. 2.2–2.3.
Die Dutch-Strategie soll den Startrang trotzdem unverändert als TPN verwenden (eine intern
abweichende Nummerierung verletzt C.04.1 Art. 9, Erklärbarkeit) und stattdessen **im Audit warnen**,
wenn die Liste nicht FIDE-sortiert ist. Eine echte Setzlisten-Funktion ist ein **Folge-Ticket**
(Vorschlag: STM-FACH-004), bewusst nicht Teil von STM-FACH-002.

## Hinweise zur Implementierung

- **Art. 1.9.3:** Ist eine Rundenpaarung nicht regelkonform möglich, entscheidet der Schiedsrichter.
  Die Strategie darf dann weder abstürzen noch stillschweigend regelwidrig paaren, sondern muss den
  Fall auditierbar an den Turnierleiter abgeben.
- **Art. 1.8:** Topscorer gibt es **nur** bei der Auslosung der Schlussrunde. In allen anderen Runden
  gilt [C3] ausnahmslos – auch an Brett 1.
- **Art. 3.8 ist der Determinismus-Anker:** Bei Gleichstand aller Kriterien gewinnt der **zuerst
  erzeugte** Kandidat. Das setzt voraus, die Erzeugungsreihenfolge aus Art. 3.6/3.7 und 4.2–4.5 exakt
  nachzubilden. Ein „nimm einfach die beste Paarung"-Ansatz reproduziert diesen Tiebreak nicht
  automatisch. bbpPairings löst es über gewichtetes Matching mit bitweise gepackten Kriterien
  (`src/swisssystems/dutch.cpp`, `computeEdgeWeight`) – die bestehende V2-Engine hat mit dem
  Bitmasken-DP bereits ein exaktes Matching für ≤ 20 Spieler, das als Baustein taugen könnte.
- **Reihenfolge zum Grünwerden:** erst Turnier A R1/R2 (einfach), dann C R3 (Art. 3.4), dann A R3
  ([C3]/[C4]), dann B R4 ([C13] + „absolut trotz −1"), zuletzt A R5 ([C20]). Die letzten beiden sind
  die härtesten.
