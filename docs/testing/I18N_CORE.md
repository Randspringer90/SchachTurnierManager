# STM-UX-001: robust i18n primitives

The existing I18nProvider now delegates language selection and template expansion
to the pure core.ts module. The existing language catalogue, context API,
language switcher, RTL handling and React text rendering are preserved.

## Fixed behaviour

- Replacement values such as $&, $$, $' and $` are literal text rather than special
  JavaScript replacement strings. One pass prevents inserted placeholders from
  being expanded again depending on object-property order.
- Fallback order remains selected dictionary, English, German. Blank/non-string
  translations fall through; a missing key stays visible instead of crashing.
- Only own dictionary/parameter properties are accepted, not prototype values.
- Stored language takes precedence; regional browser preferences are considered
  in order. Unavailable storage/navigator access is independent and harmless.
- Invalid setLang values are ignored; no unsupported lang/dir state is installed.

## Verification

From src/SchachTurnierManager.WebApp run npm run test:i18n. This optional isolated
test command requires Node 22.6+ for native TypeScript stripping. Production
build/engine constraints and dependency versions are unchanged.

Chat verification: 48/48 tests PASS on Node 22.16.0; pure core.ts strict typecheck
PASS with locally available TypeScript 5.8.3. The original index.tsx and package.json
were reconstructed byteidentically and verified against Git blob hashes before
editing. No browser UI, React rendering, full app typecheck with pinned TypeScript
6.0.3 or Vite production build was run here. Those remain integration gates.

This package does NOT translate the remaining hardcoded UI strings or declare
STM-UX-001 complete. It does not introduce HTML rendering, translation network
services, new dependencies, version bumps or a new browser-storage key.
