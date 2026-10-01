# Final Known Limitations

This list describes the current prepared packages, not a public release.

## Submission blockers

- There is no unified competition-candidate SHA yet. PR #50, PR #49 and PR #51 remain open and
  require Owner-controlled review and merge sequencing.
- Consequently, no Windows setup or signed Android test APK has been rebuilt from an exact final
  candidate SHA. Historical 0.54.1 artifacts are explicitly not accepted as final evidence.
- The public repository has no declared licence. A licence or private-jury-access decision must be
  made by the Owner after contributor-rights review.
- The Galaxy S25 installation, local-WLAN connection, result write, rotation, upgrade and
  uninstall checks remain manual.
- The configured in-app browser had no available browser instance. Responsive source/build checks
  passed, but required visual breakpoint, theme, keyboard and contrast evidence remains manual.
- A public YouTube demo, Devpost form, release, tag and public binary distribution have not been
  created. Those actions remain with the Owner.
- The primary Codex `/feedback` Session ID is still pending and must be captured in this same
  thread; the real ID must not be committed.

## Product limits

- FIDE Dutch support is substantial but is not claimed to be FIDE-certified, officially approved,
  or a complete implementation of every current edge case.
- The Android companion is a local-network client candidate, not a fully offline Android tournament
  manager and not a Play Store or F-Droid release.
- The desktop application remains the authoritative local tournament workstation. Mobile access
  depends on the PC service and local network reachability.
- German and English cover the Build Week demo path. Other registered languages are retained as
  Preview and are not represented as equally complete.
- No cloud account, advertising or tracking is required by the implemented core. Optional future
  network lookups are roadmap items and are outside this candidate.
- Large Swiss fields, full mobile pairing/result workflows beyond the current companion candidate,
  complete FIDE name search and public distribution remain roadmap work.

## Quality caveats

- The standalone contributor Pester contract uses Pester v5 syntax, while this workstation exposes
  Pester 3.4. The repository's executable ContributorKickoffReadiness gate validates the same
  generator contract and passed; upgrading test infrastructure was intentionally kept out of scope.
- Existing .NET build warnings about the preview SDK, one package reference and unused theory
  parameters remain. They did not fail the ReleaseGate but should not be hidden in final evidence.
