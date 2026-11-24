# offline-recovery-tools: scoped implementation evidence

Base of the original PR #125: d168a5a12a65dd66af18829277b7dab02c4422db.
Adopted on `integration/pr-125-safe-adoption` from the current development head.
Focused worker and build tests: 95/95 PASS (90 service-worker cases including
16 new recovery cases, plus 5 build-fingerprint cases). Repeated runs are not
additional cases.
The safe adoption changes only scanner-triggering wording (no behaviour change)
and adds a shipped-file listing check plus a guard against dependencies the
static closure parser cannot follow.
The browser setup of the original run stopped on its first navigation with an
administrator error; zero browser assertions, no bypass and no screenshot publication.
See docs/testing/OFFLINE_RECOVERY_TOOLS.md for exact scope, test method and remaining gates.
No dependency, version, model, security-policy, release or deployment change.

Addendum 2026-11-24: locally adopted from PR #129 head df77b4010aae14a3da5c615192d1b67a210c4640 after an
independent READY security review; 95/95 focused tests re-executed on the local candidate (Node 26.13.1).
See the section "Local adoption 2026-11-24" in docs/testing/OFFLINE_RECOVERY_TOOLS.md.
