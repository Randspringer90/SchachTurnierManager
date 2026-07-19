# Known limitations before submission freeze

This is the working limitations list. The final candidate must use
`FINAL_KNOWN_LIMITATIONS.md` and may only remove an item after reproducible evidence exists.

## Product

- The project is not FIDE certified or officially approved. Its FIDE-Dutch option is an
  independently implemented, audited strategy based on cited rules.
- Optimal-V2 remains the default pairing strategy. FIDE-Dutch must be selected explicitly.
- Fields above 20 active players still require dedicated performance/rules work; the documented
  fallback is not presented as a complete solution for large Opens.
- TRF16 and Swiss-Manager compatibility currently focuses on the implemented export/import
  scopes; it is not universal round-trip compatibility with every third-party feature.
- The existing language framework registers more languages than are complete. Only the final
  German and English demo path may be described as competition-ready after verification.

## Android

- The Android Companion is currently an unmerged candidate in PR #49.
- It depends on the tournament PC/server being reachable on the same local network; it is not a
  full standalone/offline Android tournament manager.
- Cleartext local-LAN communication is a test-candidate tradeoff and requires exact manifest and
  network-security review. No public-store distribution is claimed.
- Physical Galaxy S25 installation, rotation, reconnect, result entry, upgrade, and uninstall are
  still manual Owner tests.

## Windows and distribution

- The final Setup executable has not yet been rebuilt from the frozen candidate SHA.
- The Windows installer is not described as production code-signed; SmartScreen warnings may occur.
- No GitHub Release, tag, website package, F-Droid entry, Play Store entry, or public binary upload
  exists as part of this run.

## Repository and legal

- GitHub currently reports no repository license. A public competition repository therefore
  requires an Owner license decision with contributor-rights review, or a switch to the official
  private-repository jury-access path.
- The current repository history has a separately documented public-history privacy concern.
  This run does not rewrite history.

## Competition evidence

- Final scores, exact artifact hashes, CI status, video URL, and `/feedback` Session ID do not yet
  exist and must not be marked complete.
