# Marcels Schach-Work-Queue

> Kanonische Aufgabenquelle bleibt [`BACKLOG.md`](BACKLOG.md). Diese Datei bündelt die
> schachfachlichen Aufgaben, die für den Contributor (Marcel) vorbereitet sind, mit
> empfohlener Reihenfolge. Owner-/Nightly-Agenten implementieren diese Aufgaben
> **nicht** – sie sind für Marcel reserviert, solange sie ihm zugewiesen sind.

Stand: 2026-07-18.

## Arbeitsteilung

- **Marcel:** Schachregeln, Pairing, Tie-Breaks, Turnierformate, schachnahe
  Import-/Export-Funktionen.
- **Owner/KI:** Security, Infrastruktur, Agenten, Modellrouting, Nightly, Release,
  Installer, PWA, allgemeine UX.

## Queue (empfohlene Reihenfolge)

| # | Backlog-ID | Issue | Status | Abhängigkeit | Hinweis |
|---|-----------|-------|--------|--------------|---------|
| – | STM-IE-001 | [#3](https://github.com/Randspringer90/SchachTurnierManager/issues/3) | Done | – | TRF16-Export; PR #30 → Adoption #35, Merge `6a2d021` |
| – | STM-DOC-001 | [#4](https://github.com/Randspringer90/SchachTurnierManager/issues/4) | Done | – | Contributor-Doku; PR #31 → Adoption #36, Merge `aad29e1` |
| – | STM-REL-001 | – | Done | – | Windows-Installer + ContentRootPath-Bugfix; PR #33 → Adoption #34, Merge `b263925` |
| – | STM-FACH-002 | [#22](https://github.com/Randspringer90/SchachTurnierManager/issues/22) | Done | STM-FACH-001 (Done) | FIDE-Dutch; PR #40 → Adoption #45, Merge `7634399`. Entsperrt STM-FACH-003 |
| – | STM-IE-002 | [#24](https://github.com/Randspringer90/SchachTurnierManager/issues/24) | Done | STM-IE-001 (Done) | Swiss-Manager/TRF16-Import; PR #44 → Adoption #48, Merge `8f6ce32` |
| 1 | STM-FACH-003 | [#23](https://github.com/Randspringer90/SchachTurnierManager/issues/23) | Backlog (entsperrt, noch nicht Ready) | STM-FACH-002 (Done) | große Felder 21–200; auf Owner-Freigabe wartend |
| 2 | STM-FACH-011 | – | Backlog | STM-FACH-002 (Done) | Setzlisten-Vergabe nach C.04.2 Art. 2.2; post-1.0 |
| – | STM-FACH-012 | – | läuft im Owner-Draft-PR [#51](https://github.com/Randspringer90/SchachTurnierManager/pull/51) | – | UI-Auswahl Pairing-Strategie/Anfangsfarbe – **nicht parallel bearbeiten** |
| 3 | STM-IE-004 | [#25](https://github.com/Randspringer90/SchachTurnierManager/issues/25) | Backlog | – | FIDE-Namenssuche |

## Rolle

Marcel ist **`trusted-collaborator`** – siehe [`COLLABORATION_MODEL.md`](COLLABORATION_MODEL.md)
und [`config/collaboration-policy.json`](../../config/collaboration-policy.json).
Kurz: weite Arbeitsbereiche (`src/**`, `tests/**`, `docs/**`, Mobile), Owner-PRs reviewen
und Dependencies vorschlagen erlaubt; GitHub-Recht bleibt bewusst `write`.

## Regeln

- **WIP-Regel: maximal 2 Aufgaben *In Progress*, maximal 3 auf *Ready*.** Alles Weitere
  bleibt Backlog oder Blocked mit benannter Abhängigkeit.
- Nur **Ready**-Aufgaben starten; beim Start Status in `BACKLOG.md` auf *In Progress*
  setzen und Branch im Issue eintragen.
- Ein Branch/PR pro Aufgabe, Branchnamen stehen im jeweiligen Issue.
- Blocked-Aufgaben werden erst nach Abschluss ihrer Abhängigkeit auf Ready gesetzt
  (macht der Owner beim Merge der Vorgängeraufgabe).
- Fachlich kritische Pairing-Arbeit (STM-FACH-002/003) wird nie automatisch gemergt;
  der Owner führt den unabhängigen Final-Review.
