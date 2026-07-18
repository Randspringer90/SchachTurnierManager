# Final Merge Order

Status: proposed Owner sequence; no merge has been performed by the Build Week Codex run.

## 1. PR #50 — STM-INFRA-008

Review draft PR #50 at exact head
`b52a54092c9529ea5cbc744f134ddc5fb15d6d87` against
`a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`.

The package changes protected security/config/script paths. The Owner must review the exact
Android artifact attestation, the documented provenance, the negative tests, and the defensive
BAT-wrapper classification. If anything changes, the existing approval is invalid. Merge only
after the repository's required review path and CI are satisfied.

## 2. PR #49 — Android companion

After PR #50 lands, update PR #49 from the new `origin/development` without force-push. Its current
head `5aecee91afd7959c0ad368a2b86bf33c55522580` is no longer sufficient once the base changes.

Regenerate the attestation for the new PR head, repeat the complete SHA-bound static review, and
then run CI, Android lint/build, manifest and permission inspection, tracker/secret/internal-host
checks, and signature verification. The current failed CI is not a mergeable result. Do not reuse
the previous static decision or an old APK.

## 3. PR #51 — Build Week UX, demo and submission package

Update draft PR #51 from the post-Android `origin/development` without force-push. Resolve the
expected overlap in `Program.cs`, package metadata and documentation explicitly. Re-run the
SHA-bound PR review, instruction-integrity and prompt-injection gates because PR #51 changes
protected contributor-prompt tooling.

The current UX freeze remains:

`UX_FREEZE_SHA=8fbf0213bdcc57c60e0c9c9e16387dee4e994a53`

The audited product/security correction is commit
`4ea8228b70120fa62e2f71de57ab57f34a0a04dd`. Query the live PR head again at review time and bind
the static decision to that exact value; later documentation commits do not authorize new product
features. Owner review is mandatory before merge.

## 4. Candidate freeze and rebuild

Only after all three packages are integrated on `development`:

1. record the exact `development` SHA and repository version;
2. allow only P0, reproducible P1, documentation, evidence or packaging corrections;
3. run the complete ReleaseGate and release-candidate readiness;
4. build Windows setup/desktop and Android APK from that exact SHA;
5. verify hashes, signatures, manifest, permissions and artifact provenance;
6. run the manual Windows and Galaxy S25 test;
7. rebuild again if any source, build input or version changes.

No old 0.54.1 binary is the final candidate merely because it previously built or verified.
