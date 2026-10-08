# STM-UX-001: translated UI shell in all existing languages

The fifteen previously empty catalogs ar, cs, da, fr, hu, it, ja, nl, pl, pt,
ru, sv, tr, uk and zh now provide the 33 established shell keys each (495 new
entries). They are already referenced by I18nProvider; no new page, language
selection, storage setting or provider is introduced. German, English and
Spanish catalogs and the provider itself remain unchanged.

Scope: title/subtitle, backend state, language label, operator summary and
common action buttons. The product name stays SchachTurnierManager. Portuguese
uses European Portuguese and Chinese uses Simplified Chinese. The existing
Arabic RTL effect is preserved, not reimplemented in strings with direction
control characters. Technical product names SQLite and API remain recognizable.

This is NOT completion of all i18n work. Hardcoded application text and keys
introduced by other pending feature branches remain outside this package.
Partial<Messages> and the existing fallback remain intact. The content test
requires this named shell-key set, not every future key added to the base.
Preserve additional translations from other branches during integration.

## Verification

24/24 Node checks passed with Node 22.16.0: every existing catalog, shell-key
coverage, nonempty text, product name, placeholder parity, control characters
and distinct yes/no/save/delete/status labels. Against the exact old catalogs,
the same suite produced 4 PASS / 20 FAIL. All locale TypeScript files passed
strict standalone checking with locally available TypeScript 5.8.3. Neither
check replaces a native-speaker review, screen-reader/RTL review, or the full
application build with the pinned compiler.

npm run test:locales:content runs the suite; it is also prepended to the normal
build. Node type stripping requires Node 22.6 or newer. The proposed common
Node suite runner discovers this test automatically after both PRs integrate;
then it should run once, not twice via repeated build prefixes.

The 15 original placeholder files were reconstructed from the read French
file and individually verified against all 15 Git blob hashes from the live
locale tree. The unchanged de/en/es files and package.json were also bound
byte-for-byte to their current blobs before testing. No approximate baseline.

## Remaining integration gates

Full pinned React/Vite build, .NET/PowerShell/Windows suites, independent
Codex/CODEOWNERS review, browser/native-speaker validation and current CI.
Canonical BACKLOG/CHANGELOG synchronization for STM-UX-001 remains required;
do not mark the parent Done. Existing PRs #69/#72/#99 remain separate.
No dependencies, lockfile, versions, runtime policy, user worktrees or release
artifacts change. Basis: development f6f9e342277385ee3807008d2dafabdbb84cba47.
