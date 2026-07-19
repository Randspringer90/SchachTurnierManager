# Synthetic demo data

## Purpose

The Build Week demo gives a judge a useful tournament state without importing real club members,
FIDE records or personal data. Creation is explicit and local.

## Preset contract

| Field | Value |
|---|---|
| Tournament | `Build Week Demo Open` |
| Format | Swiss |
| Pairing strategy | FIDE Dutch |
| Initial colour | White |
| Planned rounds | 3 |
| Players | 8 |
| Completed rounds after creation | 1 |
| Next action | Preview/generate round 2 |

Players are named `Demo Player 01` through `Demo Player 08`. Ratings descend from 2010 to 1450.
Clubs (`Example Knights`, `Sample Rooks`), federation `SYN` and country `XX` are explicitly
fictional markers. FIDE/national IDs are null.

Round-one results use a deterministic sequence of white win, draw, black win and white win over the
generated non-bye boards. Standings therefore update immediately while the next round remains
available.

## Creation and reset

- The preset is created only after **Open demo tournament** is selected.
- If a tournament with the exact preset name exists, the action opens it rather than creating a
  duplicate.
- If initial creation fails, the WebApp attempts to remove the partial tournament and reports the
  original error.
- **More → Administration → Reset tournament** retains players/settings and deletes rounds/results
  only after a confirmation.
- Deleting the whole demo remains a separate destructive action.

## Reproducibility evidence

The isolated API smoke verifies eight players, one completed round, eight standings rows, persisted
FIDE Dutch/initial colour and a non-empty TRF16 export. The smoke deletes its test tournament and
uses a private run database rather than the user's normal data.
