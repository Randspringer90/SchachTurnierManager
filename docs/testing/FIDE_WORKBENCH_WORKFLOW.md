# STM-IE-004: FIDE lookup workspace and candidate comparison

The application entry links to /fide-workbench/index.html. Only an explicit
click reads current FIDE provider capabilities. A later explicit search uses
the existing server's FIDE search route, choosing ID or name based on input.
If that provider does not support name searches, the UI explains this and sends
NO such query. This package does not enable a missing provider implementation,
install credentials or claim that online name search is already operational.
The server may contact FIDE in response to an explicitly requested search.

Results have a fixed projection: name, FIDE ID, federation, title, three rating
values and the source's retrieval timestamp. Raw errors, profile URLs, notes,
birth years and other provider metadata are not displayed. At most 100 results
are accepted. An exact ID search must not return another FIDE ID. Responses
with conflicting identities, bad ratings or unknown statuses are rejected.

Successful/no-hit searches can be reused in a SESSION-ONLY cache (10 queries,
five minutes, no localStorage). A checkbox forces refresh. Unavailable/error
results are not cached as no-hits. Late replies from cancelled/older searches
cannot replace current results. Clearing removes the cache and all candidates.

Pin up to four different candidates across searches for side-by-side comparison
of eight fields. Differences are marked, unknown values stay unknown. Pinning
is not a duplicate-person decision, ranking algorithm or data merge. No apply,
create/update-player endpoint exists in this workflow. Existing player data
is never overwritten. Pinned values remain the originally selected values
until removed/reselected; refresh does not silently rewrite the comparison.

Tests cover both enum encodings, capabilities, query encoding, precision of
identifiers, result projection, cache limits/TTL, forced refresh, cancellation,
late replies, comparison limits and UI flow. Full provider/network/ASP.NET/
browser acceptance and independent review remain open. New behavior uses the
existing API contract read at the immutable base, not a invented FIDE schema.
#95 is a different offline-file search, not duplicated or changed here.
Canonical BACKLOG/CHANGELOG must record this part of STM-IE-004 / issue #25
before merge; complete provider-backed name search and data adoption remain
outside this delivery. See READ_ONLY_WORKFLOWS.md for transport/security limits.
