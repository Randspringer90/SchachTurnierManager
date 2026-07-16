# FIDE-Dutch – Regelreferenz für STM-FACH-002

**Zweck:** Belegquelle für alle Artikelnummern, die im Code und in den Tests der
`FideDutchPairingStrategy` zitiert werden. Diese Datei ist **keine Kopie** des FIDE-Handbuchs,
sondern eine paraphrasierte Arbeitsreferenz mit Fundstellen.

**Quellen (abgerufen am 2026-07-16):**

| Kapitel | Fassung | URL |
|---|---|---|
| C.04.1 Basic rules for Swiss Systems | gültig ab 01.02.2026 | <https://handbook.fide.com/chapter/C0401202507> |
| C.04.2 General handling rules for Swiss Tournaments | gültig ab 01.02.2026 | <https://handbook.fide.com/chapter/GeneralHandlingRulesForSwissTournaments202602> |
| C.04.3 FIDE (Dutch) System | gültig ab 01.02.2026 | <https://handbook.fide.com/chapter/C0403202602> |

> **Achtung – Fassungswechsel.** C.04.3 wurde vom FIDE Council am 28.10.2025 neu gefasst und gilt
> seit dem 01.02.2026. Die Struktur weicht **erheblich** von der bis dahin verbreiteten Fassung
> (2017er Dutch) ab: Die alte Gliederung A–E mit den Qualitätskriterien C.5–C.19 und dem zentralen
> Begriff **PSD (Pairing Score Difference)** existiert nicht mehr. Die aktuelle Fassung gliedert
> sich in Artikel 1–5 mit den Kriterien **[C1]–[C21]**; PSD kommt darin nicht mehr vor.
> Ältere Literatur, ältere Referenzimplementierungen und Vergleichspaarungen aus Tools, die noch
> auf der 2017er Fassung stehen, sind für Golden-Tests **nicht** ohne Prüfung verwendbar.

> **Achtung – veraltete Artikelnummern im Ticket.** Issue [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22)
> verweist auf „C.04.1.b" (Wiederholungsschutz) und „C.04.1.c-d" (Bye-Regeln). Dieses
> Buchstabenschema stammt aus der alten Fassung. Die inhaltlichen Anforderungen des Tickets sind
> korrekt, nur die Fundstellen sind es nicht – siehe Zuordnung unten.

---

## Zuordnung: Anforderung aus Issue #22 → aktuelle Fundstelle

| Anforderung im Ticket | Fundstelle im Ticket (veraltet) | Aktuelle Fundstelle |
|---|---|---|
| Kein Rematch | C.04.1.b | **C.04.1 Art. 2**, in Dutch **C.04.3 Art. 2.1.1 [C1]** |
| Bye-Grundregel | C.04.1.c | **C.04.1 Art. 3**, in Dutch **C.04.3 Art. 1.5** |
| Kein zweites Bye | C.04.1.d | **C.04.1 Art. 4**, in Dutch **C.04.3 Art. 2.1.2 [C2]** |
| Farbdifferenz max. ±2 | – | **C.04.1 Art. 6** |
| Keine dritte gleiche Farbe in Folge | – | **C.04.1 Art. 7** |
| Deterministische Reihenfolge | C.04.2 | **C.04.2 Art. 1.4** (Reproduzierbarkeit), **Art. 2.2–2.3** (Startnummern) |

---

## C.04.1 – Grundregeln (Artikel 1–9)

- **Art. 1:** Die Rundenzahl wird vorab bekanntgegeben.
- **Art. 2:** Zwei Teilnehmer spielen **nicht mehr als einmal** gegeneinander. → absolutes Kriterium.
- **Art. 3:** Bei ungerader Teilnehmerzahl bleibt einer ungepaart und erhält das
  *pairing-allocated bye* (PAB): kein Gegner, keine Farbe, so viele Punkte wie für einen Sieg –
  sofern die Turnierordnung nichts anderes bestimmt.
- **Art. 4:** Wer bereits ein PAB erhalten hat **oder** in einer Runde ohne zu spielen bereits die
  volle Siegpunktzahl erhalten hat, bekommt **kein weiteres** PAB.
  → Relevant für die Integration mit kampflosen Ergebnissen (STM-FACH-001).
- **Art. 5:** Grundsätzlich werden Teilnehmer mit gleicher Punktzahl gegeneinander gepaart.
- **Art. 6:** Die Differenz zwischen Schwarz- und Weißpartien eines Teilnehmers überschreitet
  **±2 nicht**.
- **Art. 7:** Kein Teilnehmer erhält **dreimal in Folge dieselbe Farbe**.
- **Art. 8:** Farbzuteilung nach bisheriger Farbverwendung und Alternierung.
- **Art. 9:** Die Paarungsregeln müssen von der auslosenden Person **erklärbar** sein.
  → Begründet, warum die Engine keine intern abweichenden Startnummern verwenden darf
  (siehe Setzlisten-Warnung).

## C.04.2 – Allgemeine Handhabung

- **Art. 1.4:** Die FIDE-Schweizer-Systeme paaren **objektiv, unparteiisch und reproduzierbar**.
  Verschiedene Schiedsrichter und verschiedene zugelassene Programme müssen zu **identischen**
  Paarungen kommen. → direkter Beleg für das Determinismus-Kriterium des Tickets.
- **Art. 1.5:** Paarungen dürfen nicht zugunsten von Norm-/Titelchancen verändert werden.
- **Art. 2.1:** Vor Turnierbeginn wird jedem Teilnehmer ein Spielstärkemaß zugeordnet.
- **Art. 2.2–2.3:** Startnummern (**TPN**, Tournament Pairing Number) werden vergeben nach
  1. Spielstärke/Rating, 2. FIDE-Titel (GM–IM–WGM–FM–WIM–CM–WFM–WCM–ohne), 3. alphabetisch.
  **Der stärkste Teilnehmer erhält die #1.** TPNs dürfen bis zur Auslosung der 4. Runde angepasst
  werden.
- **Art. 2.4–2.5:** Nachzügler erhalten keine Punkte für ungespielte Runden und bekommen ihre TPN
  bei Zulassung.
- **Art. 3.4:** Ungespielte Runden bleiben bei der **Farbfolge unberücksichtigt**; die Historie wird
  behandelt, als hätte die Runde nicht stattgefunden.
  → Wichtig für Forfeits: sie zählen **nicht** in Farbdifferenz/Farbfolge.
- **Art. 3.5:** Zwei Teilnehmer, die nicht gegeneinander gespielt haben (kampflos), dürfen später
  noch gegeneinander gepaart werden.
- **Art. 3.6:** Bretter werden sortiert nach höchster Punktzahl, dann Punktsumme, dann niedrigster TPN.

## C.04.3 – FIDE (Dutch) System

### Artikel 1 – Definitionen

- **1.1** TPN. **1.2 Order:** Sortierung nach Punkten absteigend, TPN aufsteigend.
  → In der Auslosung zählt **nur** Punkte + TPN. Das Rating ist bereits in der TPN aufgegangen
  (C.04.2 Art. 2.2) und wird **nicht erneut** herangezogen.
- **1.3.1 Scoregroup:** alle Spieler mit derselben Punktzahl.
- **1.3.2 Bracket:** die zu paarende Gruppe – Spieler aus einer Punktgruppe (*resident players*)
  plus ggf. Spieler, die im vorigen Bracket ungepaart blieben.
- **1.3.3:** Bracket ist **homogen**, wenn alle dieselbe Punktzahl haben, sonst **heterogen**.
- **1.4.1 Downfloater / MDP:** Wer in einem Bracket ungepaart bleibt, wandert ins nächste Bracket
  und heißt dort *moved-down player* (MDP).
- **1.4.2–1.4.3:** Spielen zwei Spieler mit unterschiedlicher Punktzahl gegeneinander, erhält der
  höher platzierte einen **Downfloat**, der niedrigere einen **Upfloat**. Ein Downfloat erhält auch,
  wer ein PAB bekommt oder ohne zu spielen mehr als die Niederlagenpunktzahl erhält.
- **1.4.4:** Andere Spieler erhalten **keine** Floats.
- **1.5 PAB:** siehe C.04.1 Art. 3.
- **1.6 Colour difference:** Weißpartien minus Schwarzpartien.
- **1.7 Colour preference:**
  - **1.7.1 absolut:** Farbdifferenz > +1 oder < −1, **oder** dieselbe Farbe in den beiden letzten
    gespielten Runden. Präferenz Weiß bei Differenz < −1 bzw. zweimal Schwarz zuletzt; Schwarz bei
    Differenz > +1 bzw. zweimal Weiß zuletzt.
  - **1.7.2 stark:** Farbdifferenz +1 (Präferenz Schwarz) bzw. −1 (Präferenz Weiß).
  - **1.7.3 mild:** Farbdifferenz 0; Präferenz ist das Alternieren zur zuletzt gespielten Farbe.
- **1.8 Topscorers:** Spieler mit **über 50 % der maximal möglichen Punktzahl – bei der Auslosung
  der SCHLUSSRUNDE**. Vor der Schlussrunde gibt es also **keine** Topscorer.
  → Konsequenz: [C3] (Art. 2.1.3) gilt in allen Runden außer der Schlussrunde **ausnahmslos**.
  Zwei Spieler mit derselben absoluten Farbpräferenz dürfen dort nie gegeneinander – auch nicht
  an Brett 1. Ebenso greifen [C10]/[C11] (Topscorer-Sonderregeln) nur in der Schlussrunde.
- **1.9 Round-Pairing Outlook:**
  - **1.9.1:** Die Rundenpaarung ist vollständig, wenn alle Spieler gepaart sind – höchstens einer
    floatet aus dem letzten Bracket ab und erhält das PAB – und [C1]–[C3] eingehalten sind.
  - **1.9.2:** Der Prozess startet bei der **obersten** Punktgruppe und läuft Bracket für Bracket
    in absteigender Reihenfolge.
  - **1.9.3:** Ist eine Rundenpaarung **unmöglich**, entscheidet der **Schiedsrichter**.
    → Umsetzung: Die Strategie darf in diesem Fall weder abstürzen noch stillschweigend eine
    regelwidrige Paarung liefern. Sie muss den Fall als solchen melden und an den Turnierleiter
    abgeben (auditierbar, vgl. C.04.1 Art. 9).

### Artikel 2 – Paarungskriterien

**2.1 Absolute Kriterien** (dürfen nie verletzt werden):
- **2.1.1 [C1]:** Zwei Teilnehmer spielen nicht mehr als einmal gegeneinander.
- **2.1.2 [C2]:** Kein zweites PAB (vgl. C.04.1 Art. 4).
- **2.1.3 [C3]:** **Nicht-Topscorer mit derselben absoluten Farbpräferenz treffen nicht aufeinander.**

**2.2 Completion Criterion:**
- **2.2.1 [C4]:** Für alle noch nicht gepaarten Spieler muss stets eine Paarung existieren, die alle
  absoluten Kriterien erfüllt. → begründet das Backtracking.

**2.3 PAB Criterion:**
- **2.3.1 [C5]:** Die Punktzahl des PAB-Empfängers **minimieren**.
  → Präzisierung der Ticket-Formulierung „regelkonform niedrigst platzierter Spieler".

**2.4 Qualitätskriterien** (absteigende Priorität):

| Kriterium | Artikel | Inhalt (paraphrasiert) |
|---|---|---|
| [C6] | 2.4.1 | Zahl der Downfloater minimieren (= Zahl der Paare maximieren) |
| [C7] | 2.4.2 | Punktzahlen der Downfloater (absteigend betrachtet) minimieren |
| [C8] | 2.4.3 | Downfloater-Menge so wählen, dass im Folge-Bracket [C1]–[C7] erfüllbar bleiben |
| [C9] | 2.4.4 | Zahl der ungespielten Partien des PAB-Empfängers minimieren |
| [C10] | 2.4.5 | Topscorer/Topscorer-Gegner mit Farbdifferenz > +2 minimieren |
| [C11] | 2.4.6 | Topscorer/Topscorer-Gegner mit dreimal gleicher Farbe minimieren |
| [C12] | 2.4.7 | Spieler ohne erfüllte Farbpräferenz minimieren |
| [C13] | 2.4.8 | Spieler ohne erfüllte **starke** Farbpräferenz minimieren |
| [C14] | 2.4.9 | Resident-Downfloater, die schon in der Vorrunde downgefloatet sind, minimieren |
| [C15] | 2.4.10 | MDP-Gegner, die schon in der Vorrunde upgefloatet sind, minimieren |
| [C16] | 2.4.11 | Resident-Downfloater mit Downfloat vor zwei Runden minimieren |
| [C17] | 2.4.12 | MDP-Gegner mit Upfloat vor zwei Runden minimieren |
| [C18] | 2.4.13 | Punktdifferenzen (absteigend) der downgefloateten MDPs minimieren |
| [C19] | 2.4.14 | Punktdifferenzen (absteigend) der upgefloateten MDP-Gegner minimieren |
| [C20] | 2.4.15 | wie [C18], bezogen auf zwei Runden vorher |
| [C21] | 2.4.16 | wie [C19], bezogen auf zwei Runden vorher |

→ **[C14]–[C17]** sind die Float-Historie („kein doppelter Absteiger") aus dem Ticket.

### Artikel 3 – Paarungsprozess je Bracket

- **3.1:** `M0` = Zahl der MDPs aus dem vorigen Bracket (kann 0 sein). `MaxPairs` = maximal mögliche
  Paarzahl im Bracket (vgl. [C6]). `M1` = Zahl der im Bracket gepaarten MDPs.
- **3.2:** Bracket wird in **S1** und **S2** geteilt. Homogen: S1 = die ersten `MaxPairs` Spieler nach
  TPN-Reihenfolge. Heterogen: S1 = erste Menge paarbarer MDPs (Art. 4.4.2). S2 = alle übrigen
  Residents. **Limbo (3.2.4):** Ist `M1 < M0`, sind `M0 − M1` MDPs weder in S1 noch in S2 – sie sind
  im Limbo, können im Bracket nicht gepaart werden und floaten zwangsläufig erneut ab.
- **3.3:** S1 wird der Reihe nach gegen S2 gepaart (erster mit erstem usw.). Homogen: Paare +
  ungepaarte Spieler = **Kandidat**. Heterogen: `M1` MDPs aus S1 gegen `M1` Residents aus S2 =
  **MDP-Pairing**; die übrigen Residents bilden den **Remainder**, der nach homogenen Regeln
  weiterverarbeitet wird. Kandidat = MDP-Pairing + Kandidat des Remainders; Limbo-Spieler sind
  gesetzte Downfloater.
- **3.4:** Erfüllt der Kandidat [C1]–[C5] **und** alle Qualitätskriterien [C6]–[C21], heißt er
  **perfekt** und wird sofort angenommen. Sonst Art. 3.5, bzw. Art. 3.8 wenn kein perfekter Kandidat
  existiert.
- **3.5:** S1/Limbo/S2 werden verändert, um einen anderen Kandidaten zu erzeugen; nach jeder
  Änderung neu bauen (3.3) und bewerten (3.4). Reihenfolge der Änderungen: Art. 3.6 (homogen),
  Art. 3.7 (heterogen).
- **3.6 (homogen):** zuerst **Transposition** in S2 (Art. 4.2). Sind keine Transpositionen mehr
  verfügbar, **Exchange** zwischen S1 und S2 (Art. 4.3), danach S1/S2 nach Art. 1.2 neu sortieren.
- **3.7 (heterogen):** zuerst den Remainder nach den homogenen Regeln behandeln (Subgruppen heißen
  dort **S1R/S2R**). Sind dort Transpositionen und Exchanges erschöpft, Transposition in S2 → neues
  MDP-Pairing und ggf. neuer Remainder. Sind auch die erschöpft, nächste Menge paarbarer MDPs aus
  S1/Limbo wählen (Art. 4.4.2) und S2 auf Originalzustand zurücksetzen.
- **3.8:** Existiert kein perfekter Kandidat, wird der **beste verfügbare** gewählt: besser ist, wer
  [C5] oder ein höherpriorisiertes Qualitätskriterium [C6]–[C21] besser erfüllt; bei Gleichstand
  aller Kriterien gewinnt der **früher erzeugte** Kandidat.
  → **Das ist der Determinismus-Anker:** Die Erzeugungsreihenfolge aus Art. 3.6/3.7 und 4.2–4.5
  entscheidet, und sie ist vollständig definiert. Kein Zufall, kein Tiebreak „nach Gefühl".

### Artikel 4 – Erzeugungsreihenfolge

- **4.1 BSN:** Vor Transpositionen/Exchanges erhalten alle Spieler des Brackets bzw. Remainders
  fortlaufende *In-Bracket Sequence Numbers* (1, 2, 3, …) gemäß ihrer Reihenfolge nach Art. 1.2.
- **4.2 Transpositionen:** Änderung der Reihenfolge der (Resident-)BSNs in S2. Alle möglichen
  Transpositionen werden nach dem **lexikografischen Wert ihrer ersten N1 BSNs** sortiert
  (N1 = Anzahl BSNs in S1).
- **4.3 Exchanges (homogen):** Tausch zweier **gleich großer** BSN-Gruppen zwischen ursprünglichem S1
  und S2. Sortierung: (1) kleinste Zahl getauschter BSNs, (2) kleinste Differenz der BSN-Summen,
  (3) größte abweichende BSN von S1 nach S2, (4) kleinste abweichende BSN von S2 nach S1.
- **4.4 Paarbare MDP-Mengen:** Eine Menge ist gültig, wenn der verbleibende Limbo [C7] erfüllt.
  Gültige Mengen werden nach ihrer **kleinsten abweichenden BSN** sortiert.
- **4.5 Next Element:** Wo immer Art. 4.2–4.4 eine Ordnung festlegen, wird bei Anwendung das
  **nächste Element** dieser Ordnung gewählt.

### Artikel 5 – Farbzuteilung

- **5.1 initial-colour:** wird **vor der Auslosung der ersten Runde ausgelost**.
  → Losentscheid, keine Berechnung. Muss im Turnier gespeichert werden, sonst ist die Auslosung
  nicht reproduzierbar (Widerspruch zu C.04.2 Art. 1.4). Umsetzung im Projekt:
  `TournamentSettings.SwissInitialColour`, Standard Weiß, vom Turnierleiter setzbar.
- **5.2 Priorität (absteigend):**
  - **5.2.1** Beide Farbpräferenzen erfüllen.
  - **5.2.2** Die **stärkere** Präferenz erfüllen; sind beide absolut, die **größere Farbdifferenz**
    bevorzugen.
  - **5.2.3** Farben so alternieren, dass sie zur jüngsten Runde passen, in der einer Weiß und der
    andere Schwarz hatte.
  - **5.2.4** Präferenz des **höher gesetzten** Spielers erfüllen.
  - **5.2.5** Hat der höher gesetzte Spieler eine **ungerade TPN**, erhält er die initial-colour,
    sonst die Gegenfarbe.

---

## Gegenprobe gegen eine Referenz-Engine

**C.04.2 Art. 1.4** verlangt, dass verschiedene zugelassene Programme zu **identischen** Paarungen
kommen. Der Abgleich gegen eine Referenz-Engine ist damit nicht bloß eine zweite Meinung, sondern
der von der Regel selbst definierte Maßstab für „richtig".

| | |
|---|---|
| **Engine** | bbpPairings 6.0.0 (Apache-2.0) |
| **Erschienen** | 2026-02-01 — dem Tag des Inkrafttretens der neuen C.04.3-Fassung |
| **Bezug** | <https://github.com/BieremaBoyzProgramming/bbpPairings/releases/tag/v6.0.0> |
| **Endorsement** | Engine hinter SwissSys (FIDE-endorsed, Presidential Board Minsk 2018) |
| **Geprüft am** | 2026-07-16 |

**Ergebnis (Golden-Turnier A, Runde 3):** alle vier Paare und alle acht Farben identisch zur
Handherleitung — 1–8, 3–6, 7–2, 5–4. Bestätigt wurden damit insbesondere die beiden Punkte mit dem
höchsten Irrtumsrisiko: die Absteigerwahl nach **[C7]** und die Sortierung der Transpositionen nach
**Art. 4.2**. Die von der Engine ausgegebene Checkliste bestätigte zusätzlich die
Farbpräferenz-Einstufung (absolut/mild) Spieler für Spieler.

**Wichtig zur Auswahl der Engine:** Swiss-Manager und Vega nutzen **JaVaFo** als Paarungs-Engine –
ein Abgleich gegen sie ist also *kein* unabhängiger Gegentest zu JaVaFo. Es existieren praktisch
nur zwei unabhängige Implementierungen: **JaVaFo** (Ricca) und **bbpPairings** (Bierema Boyz).
Eine Version, die noch die 2017er Fassung umsetzt, ist als Referenz **unbrauchbar** – sie würde
Fehler gegen ein abgelaufenes Regelwerk bestätigen.

Reproduzierbar über `tmp/build-dutch-trf.ps1` (erzeugt die TRF-Eingabe; Spaltenformat verifiziert
gegen `test/tests/dutch_2025_C5.input` aus dem bbpPairings-Repo) und `tmp/GEGENTEST-ANLEITUNG.md`.
`tmp/` ist gitignored – die Dateien sind Arbeitsmaterial, nicht Teil des Repos.

---

## Abweichungen und offene Punkte im Projekt

1. **Setzliste nicht in TPN-Reihenfolge.** `TournamentService.NormalizePlayerForSave` vergibt
   Startränge als **Eingabereihenfolge** (`tournament.Players.Count + 1`), nicht nach Spielstärke.
   Das widerspricht C.04.2 Art. 2.2–2.3. Die Dutch-Strategie verwendet den Startrang trotzdem
   unverändert als TPN – eine intern abweichende Nummerierung würde C.04.1 Art. 9 (Erklärbarkeit)
   verletzen. Stattdessen **warnt** die Strategie im Audit, wenn die Startliste nicht nach
   C.04.2 Art. 2.2 sortiert ist. Eine Setzlisten-Funktion ist Gegenstand eines Folge-Tickets.
2. **Accelerated Pairing (C.04.5)** ist nicht Teil von STM-FACH-002.
3. **Felder > 20 Spieler:** Performance ist Gegenstand von STM-FACH-003.
