# STM-IE-004: offline FIDE name search

Part of issue #25. A user opens /fide-search/index.html, selects an already
unpacked standard-rating TXT list and explicitly searches by name tokens or
FIDE ID, optionally filtered by a three-letter federation. Searching never
contacts FIDE, edits players, selects a person automatically or uploads files.
The FIDE ID can be manually reused in the existing lookup workflow.

The header drives fixed-width column boundaries. Supported required labels:
ID Number, Name, Fed and exactly one of SRtng/STD. Extra columns serve as
boundaries but their personal fields are not returned. Required fields cannot
be last in the header. TXT column positions are interpreted as Unicode scalar
columns; UTF-8 decoding is strict. This is a documented subset, not a generic
parser for all historical/current FIDE formats. ZIP/XML, rapid-only/blitz-only
headers, malformed rows and incomplete reads are rejected without publishing
partial matches. Displayed title codes use the documented FIDE abbreviations.

Names are matched accent-insensitively with every query token required. FIDE IDs
match exactly. File order is retained; at most 50 rows appear, with full match
and omitted counts after the entire file is scanned. Duplicate records in an
input list are not globally deduplicated; counts refer to rows, not unique
verified people. The caller must verify list origin and rating date.

Streaming avoids loading a whole list of player objects. Limits: 256 MiB input,
2 million records, 1024 characters per line, 100-character query. The UI yields
between batches, reports progress and supports cancellation. Changing an input
or cancelling invalidates late output. A 10,000-record synthetic scan is tested;
full-size real FIDE lists and browser responsiveness are NOT_RUN here.

Offline lookup is one part of #25: no backend provider abstraction, cached
online name service, field adoption, TTL, or end-to-end confirmed overwrite is
claimed. It does not take over another contributor's reserved implementation.

68/68 focused tests PASS: core and UI races, full scan counts, malformed data,
UTF-8 chunk boundaries, cancellation and text-only rendering. An initial decoder
error classification defect was reproduced with a failing test and corrected.

Official label legend consulted on 2026-10-02 (the retrieved page snapshot lists
July 2026; it is not evidence of the latest rating month):
https://ratings.fide.com/download_lists.phtml
Streaming File API: https://www.w3.org/TR/FileAPI/

## Integration and evidence boundaries

Base: development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
Entry HTML and package.json were reconstructed and byte-verified against their
Git blob hashes before modification. No user workstation or existing PR branch
was modified. The new entry link and npm test command must be merged additively
with ALL other pending links/build commands; never replace an integrated file
with this branch's older baseline. The shared ui-harness.mjs is identical across
the three packages. No dependencies, lockfiles, versions or security policies
were changed. The existing full TypeScript/Vite build follows the added tests.

The focused Node tests run on Node 22.16.0. Tests using DOM adapters are not
browser, accessibility, React, ASP.NET hosting or full application evidence.
Full pinned build, .NET/PowerShell gates, Commit-If-Green, independent
Codex/CODEOWNERS review and green remote CI remain required. No browser
acceptance test was executed in this run. New static .js assets are not
automatically added to the pending PWA precache; no full offline-app guarantee.

Keep the existing parent task open until its entire original acceptance scope
is fulfilled. The linked PR supplies only the feature described here, not a
release/merge authorization. Synchronize the canonical BACKLOG/CHANGELOG on
integration before marking anything Done. No runtime logs, real rating lists,
personal backups, secrets, screenshots or other visual artifacts are published.
