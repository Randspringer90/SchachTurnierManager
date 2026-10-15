# STM-SEC-003: private, truthful crash fallback

The existing top-level React ErrorBoundary now stores only hasError. It does
not inspect, stringify or retain the thrown value. Neither raw error messages
nor stacks are copied into the fallback UI or this boundary's console call.
The sole diagnostic is the fixed reference UI_RENDER_FAILURE.

The bilingual fallback does not depend on a working i18n context. It no longer
asserts that saved tournament data is unaffected: a render failure cannot tell
whether the last mutation reached durable storage. It asks the user to check
the tournament state and warns that unsaved input may be lost on reload/leave.
The only retry is the existing explicit reload button. A fixed same-tab link
opens the already integrated local backup reader. Nothing is re-imported,
replayed, deleted, sent to a provider or automatically reloaded.

## Privacy and recovery limits

React 19's default root handlers log the raw thrown value (message and stack)
even in production builds. `main.tsx` therefore creates the root with
`createPrivateRootErrorOptions(import.meta.env.DEV)`: in production the caught
and uncaught handlers log only `UI_RENDER_FAILURE` and the recoverable handler
only `UI_RECOVERABLE_ERROR`; the raw value is forwarded only on the local Vite
development server. Browser tooling, other loggers and the original thrown
object elsewhere remain outside this boundary's control. This is not product-wide log redaction, error
suppression, anonymization or an assertion of intact database state. Removing
payload details trades local debugging detail for a stable safe error reference.
The existing class and reload CSS contracts are preserved.

The backup-reader link already exists on the base. Offline availability of its
static files is supplied by the separate STM-UX-002 recovery-cache package and
requires a successful earlier online worker installation. This error-boundary
change does not promise offline availability by itself.

## Executed verification

21/21 tests PASS on Node 24 with the pinned WebApp TypeScript (`npm ci`), and
`tsc --noEmit` passes. The original 18 tests gave 4 PASS / 14 FAIL against the
unchanged boundary. They compile the actual TSX with the already declared
TypeScript package and execute its class with a small React element adapter.
Review follow-up added: redaction over all rendered attributes, production and
development root handlers, and the `main.tsx` root wiring.

The tests exercise normal children, unusual/hostile thrown values, state and
render redaction, fixed diagnostic arguments, persistence uncertainty, unsaved
input warning, the explicit reload callback and fixed same-tab recovery link.
These are lifecycle/render contracts, not real React reconciliation or a browser
mount. The new top-level *.test.mjs is reachable by the existing Node-suite
runner; no dependency, package.json or CI-workflow edits are needed.

Real React/browser, keyboard/screen-reader and full pinned build acceptance
remain open. The shared browser setup attempt was administratively blocked
before its first navigation; this React component was not mounted in it.
React contract checked 2026-10-08:
https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary

## Publication and integration gates

Base: development d168a5a12a65dd66af18829277b7dab02c4422db. No dependencies,
lockfiles, product versions, releases or deployments change. Exact-SHA local
gates, required GitHub CI and the independent AI review are recorded in the
pull request. Other places that show raw API/parse error text in the UI
(`api/client.ts` describeApiError, the JSON import parse message in `App.tsx`)
are outside this change and tracked as STM-SEC-003 follow-ups; the parent task
remains partial and is not counted as newly Done.
