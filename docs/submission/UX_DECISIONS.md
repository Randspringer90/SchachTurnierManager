# Build Week UX decisions

Status: 2026-07-18
Decision owner: repository Owner; implementation prepared by the primary Codex thread

## Product hierarchy

The primary navigation is **Overview → Participants → Round → Standings → More**. Assistant,
print/export/backup, audit and administration remain intact behind More. This reduces competing
top-level actions without deleting expert capability.

## Onboarding and demo data

- Nothing is imported automatically.
- “Open demo tournament” creates one named, local tournament only after an explicit click.
- The preset contains eight `Demo Player NN` records, synthetic clubs, fictional federation/country
  markers, varied ratings, one completed round and a non-empty standings table.
- Reopening the action selects an existing demo instead of silently duplicating it.
- The existing reset action keeps players/settings and removes rounds only after confirmation.

## Pairing strategy

- Optimal V2 remains the default for new and legacy tournaments.
- FIDE Dutch is an explicit advanced selection for Swiss tournaments.
- Initial colour is visible only when FIDE Dutch is selected.
- Strategy and initial colour become immutable in the UI after round one, matching the existing
  format guard and avoiding a mid-event silent switch.
- Text explicitly avoids any FIDE certification or approval claim.

## Operational safety

- Result selection opens a confirmation step rather than writing on change.
- The last confirmed result can be undone once; both operations use the normal audited API path.
- Reset and delete stay spatially separated in Administration.
- Absolute database and runtime-log paths are removed from the public health contract and UI.

## Progressive disclosure

- Pairing strategy is under Advanced during creation.
- The standings show rank, player, points, wins, Buchholz and Sonneborn-Berger first.
- Additional tie-break columns, Hero Cup, category standings, cross table and bye/forfeit audit
  are revealed together only after the user asks for more standings detail.
- Pairing quality and Chess960 controls are collapsed expert sections in the Round view; per-board
  Chess960 actions remain available inside that section rather than competing with result entry.
- Dense exports such as TRF16 and Swiss-Manager are grouped under More, not promoted as the normal
  first action.

## Accessibility and responsive behaviour

- Core controls use approximately 44 px minimum height.
- Keyboard focus is visible and does not rely on colour alone.
- Result controls have board-specific accessible names.
- A five-item mobile navigation is fixed above the safe-area inset at widths up to 720 px.
- Reduced-motion behaviour from the existing design system is retained.
- Light/dark preference is local-only.

## Dependency decision

No UI framework or new runtime dependency was added. The existing React/TypeScript/CSS foundation
is sufficient and avoids an unnecessary supply-chain and bundle-size delta immediately before the
submission freeze.
