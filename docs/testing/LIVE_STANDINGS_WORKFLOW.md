# STM-UX-012: explicit live standings display

The application entry links to /live-standings/index.html. Load the tournament
list, choose a tournament, then explicitly start the display. Manual-only is
the default; optional intervals are 15, 30 or 60 seconds. Refreshes are serial
and scheduled after completion, not overlapping timer ticks. Pause stops the
timer and active request. Hidden tabs suspend requests and resume only if the
operator previously enabled the running state. Leaving the page cleans up.

The backend alone determines ranking and tiebreak values. The view preserves
its order and shows rank, points, Buchholz, Sonneborn-Berger and wins. Name
filtering and pagination never recalculate rank. Names start hidden; their
checkbox explicitly reveals them. Presentation mode enlarges the SAME page,
not a new browser/window. Selection changes clear both prior rows and the old
refresh target. A failed update retains the last good rows with an explicit
stale marker and last-success time; new tournament failures cannot show rows
from the previous tournament. Pagination offers 10, 20 or 50 rows.

This is a trusted local club/operator display, NOT a hardened public kiosk.
The existing API is not access controlled by this UI. In particular the list
endpoint returns full tournament states; see READ_ONLY_WORKFLOWS.md. No scores
are entered or updated, no pairing logic is duplicated. Results/round changes
can happen between HTTP requests; this is not an atomic synchronized snapshot.

Tests cover projection, validation, preserved backend rank, filtering/paging,
serial polling, stale data, selection/visibility/pause/cleanup and UI controls.
A synthetic DOM adapter initially missed heading tags; the adapter was corrected
without changing production behavior. Real browser/Windows acceptance remains
open. Canonical BACKLOG/CHANGELOG must record this scoped STM-UX-012 package
before merge, without marking the entire parent complete. Other existing PRs
and the main.tsx refactor remain untouched.
