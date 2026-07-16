# Marcels Schach-Work-Queue

> Kanonische Aufgabenquelle bleibt [`BACKLOG.md`](BACKLOG.md). Diese Datei bündelt die
> schachfachlichen Aufgaben, die für den Contributor (Marcel) vorbereitet sind, mit
> empfohlener Reihenfolge. Owner-/Nightly-Agenten implementieren diese Aufgaben
> **nicht** – sie sind für Marcel reserviert, solange sie ihm zugewiesen sind.

Stand: 2026-07-16.

## Arbeitsteilung

- **Marcel:** Schachregeln, Pairing, Tie-Breaks, Turnierformate, schachnahe
  Import-/Export-Funktionen.
- **Owner/KI:** Security, Infrastruktur, Agenten, Modellrouting, Nightly, Release,
  Installer, PWA, allgemeine UX.

## Queue (empfohlene Reihenfolge)

| # | Backlog-ID | Issue | Status | Abhängigkeit | Hinweis |
|---|-----------|-------|--------|--------------|---------|
| 1 | STM-IE-001 | [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) | **Ready** | – | TRF16-Export; Golden-Datei, Determinismus, PII-Minimierung im Issue präzisiert |
| 2 | STM-DOC-001 | [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) | **Ready** | – | parallel oder nach #3 möglich (frischer Clone als Prüfgrundlage) |
| 3 | STM-FACH-002 | [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22) | **Ready** | STM-FACH-001 (Done) | FIDE-Dutch; fachlich kritisch → Final-Review durch unabhängigen Owner-Prozess mit stärkstem Review-Profil |
| 4 | STM-FACH-003 | [#23](https://github.com/Randspringer90/SchachTurnierManager/issues/23) | Blocked | STM-FACH-002 | große Felder 21–200; erst nach FACH-002 starten |
| 5 | STM-IE-002 | [#24](https://github.com/Randspringer90/SchachTurnierManager/issues/24) | Blocked | STM-IE-001 | Swiss-Manager/Chess-Results-Kompatibilität |
| 6 | STM-IE-004 | [#25](https://github.com/Randspringer90/SchachTurnierManager/issues/25) | Backlog | – | FIDE-Namenssuche; bewusst hinten, um die Queue nicht zu überladen |

## Regeln

- Nur **Ready**-Aufgaben starten; beim Start Status in `BACKLOG.md` auf *In Progress*
  setzen und Branch im Issue eintragen.
- Ein Branch/PR pro Aufgabe, Branchnamen stehen im jeweiligen Issue.
- Blocked-Aufgaben werden erst nach Abschluss ihrer Abhängigkeit auf Ready gesetzt
  (macht der Owner beim Merge der Vorgängeraufgabe).
- Fachlich kritische Pairing-Arbeit (STM-FACH-002/003) wird nie automatisch gemergt;
  der Owner führt den unabhängigen Final-Review.
