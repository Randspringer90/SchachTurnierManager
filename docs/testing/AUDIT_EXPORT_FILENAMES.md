# STM-IE-012: portable audit download names

AuditForensicExportBuilder now applies a fixed cross-platform filename policy
instead of asking the server OS for invalid characters. Both JSON and JSONL
use it. This changes only the suggested download filename, not audit payloads,
tournament names, the schema, timestamps, ordering, or storage operations.

The stem replaces Windows filename metacharacters, Unicode controls/formatting
characters and whitespace with underscores. Leading/trailing whitespace and
outer dots are trimmed. An empty/dot-only result uses Turnier. The stem is
limited to 120 UTF-8 bytes and truncation stops before a complete Unicode
scalar; non-ASCII names and supplementary characters remain supported.
The fixed _round..._timestamp_audit.json[l] suffix is preserved and makes a
stem such as CON a non-device filename. This private helper is not a generic
standalone path validator and must not be used without the audit suffix.

No guarantee of collision-free filenames, a bounded full destination path,
grapheme-preserving truncation, anonymization, or automatic file overwrite
protection is added. Existing same-second name collisions remain possible.

## Verification and scope

46 synthetic xUnit cases added via the existing Domain.Tests project. Both
export formats cover platform metacharacters, Unicode, controls, dot-only
names, a device-like stem, byte bounds, nonmutation, manifest preservation
and truncation next to a supplementary character. Existing tests unchanged.

C# compilation and all 46 cases are NOT_RUN in the chat environment; .NET is
not installed and toolchain download was unavailable. Source review and
byte/whitespace validation are not an executable C# test pass. Run the full
Domain/Application/export suites and required project gates before merge.
Independent Codex/CODEOWNERS review and current CI remain required.

The original builder matches Git blob
3fabaa98560f2073b32803321fa82da562a60364 on development and on #55's inspected
head. Only its private filename method changed. Other export formatters,
CSV review fixes, pending integration branches and user worktrees are untouched.

Canonical integration entries: STM-IE-012, In Review, import-export, owner,
v1.0.0. CHANGELOG: audit downloads use bounded portable filename stems.
BACKLOG/CHANGELOG still require canonical synchronization before merge.

API reference checked 2026-10-01:
https://learn.microsoft.com/dotnet/api/system.io.path.getinvalidfilenamechars
https://learn.microsoft.com/dotnet/api/system.text.rune
