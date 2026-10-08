# STM-UX-001: static translation catalogue audit

Test-I18nCatalogs.mjs reads the flat src/i18n/locales/*.ts catalogue directory.
The existing WebApp TypeScript compiler parses syntax into an AST. Catalogue
modules are never imported, transpiled into executable code or evaluated.
Literal exported const objects, type-only imports, type declarations and as-const/
satisfies wrappers are supported; computed fields, spreads, expressions, calls,
getters and executable statements are rejected rather than silently ignored.

The German catalogue defines the key set. Duplicate or unknown keys, empty values
and changed placeholder-name sets fail. Placeholder syntax is exact: any brace
outside a `{identifier}` placeholder (e.g. `{{name}}`, `{name`, `name}`, `{ name }`)
fails as `placeholderSyntaxErrors` in every catalogue including German, because the
runtime would render the stray braces. Placeholder order and repetitions may
vary with language grammar. Missing translations remain visible as PARTIAL by
default, preserving the existing Partial<Messages>/fallback design. Passing
--require-complete makes missing translations fail too. An empty/missing German
catalogue cannot produce a vacuous pass. Reports list keys and counts, not full
translation values, local paths or raw compiler/filesystem errors.

## Commands and build integration

From the WebApp directory: npm run test:catalogs and npm run audit:i18n.
For strict completeness: npm run audit:i18n -- --require-complete.
The normal npm build runs the tests and audit before tsc/Vite. No package version,
dependency or lockfile changes. TypeScript is resolved from the WebApp's existing
dependencies, not downloaded by this tool. File count and byte sizes are bounded;
non-regular catalogue entries and invalid UTF-8 are rejected. This is an offline
quality check, not an adversarial filesystem sandbox or a complete TypeScript
semantic compiler replacement.

## Evidence and limits (2026-10-01)

69/69 Node tests passed, 0 failures/skips; actual npm test command also passed.
An actual CLI run against byte-verified current de.ts/en.ts found 33 base keys,
two complete catalogues and zero errors. Only those two repository catalogues were
available for that local sample, not the entire multilingual tree. Compiler used
here: locally installed TypeScript 5.8.3; Node 22.16.0. The project's pinned
TypeScript 6.0.3, all locales, full Vite/.NET/PowerShell gates and browser behaviour
remain NOT_RUN here and are required at integration. No linguistic accuracy,
complete UI translation or independent code review is claimed.

The CLI resolves its entrypoint physically so a symlink/junction does not turn
a requested audit into a silent zero-exit no-op. A real symlink invocation was
reproduced before the fix (empty output) and returned the expected audit after it.

## Integration

Refs #68; complements #69 without changing its runtime core or locale texts.
Keep #69's test:i18n script and #71's test:pwa/prebuild additions when reconciling
package.json. Add these tests/audit ahead of the final combined tsc/Vite build;
do not replace newer dependency/Android metadata with this older branch base.
Canonical BACKLOG/CHANGELOG synchronization and final CI/independent review remain
open. The broader STM-UX-001 translation task is not closed by this delivery.
