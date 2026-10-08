# STM-IE-011: BOM-directed Unicode imports

Issue: #85. Scope: ImportTextDecoder, already called by Swiss-Manager and TRF
byte imports. No changes to pairing, persistence, CSV delimiters or TRF columns.

## Behaviour

Complete BOMs select strict UTF-8, UTF-16 LE/BE or UTF-32 LE/BE. UTF-32 is
checked before UTF-16 because their LE prefixes overlap. Only the initial
signature is removed; a subsequent U+FEFF and original line endings remain.
Malformed declared Unicode produces ArgumentException without decoder byte
snippets or inner exceptions. The existing API handles ArgumentException.

Unmarked files retain strict UTF-8 first and Windows-1252 fallback. This is not
an encoding detector: BOM-less UTF-16/32 and other code pages are not guessed.
A partial signature is not treated as a complete BOM. Invalid BOM-marked UTF-8
previously tolerated through fallback is intentionally rejected instead.
Correct decoding does not imply that a file's delimiters/schema are supported.

## Verification

33 synthetic xUnit cases added: all five BOM variants, signature-only files,
embedded U+FEFF, line endings, malformed Unicode, unmarked legacy compatibility,
nonmutation, null input and decoder-to-Swiss-Manager parser integration.
The original decoder blob d3e7c37e9c7320c6a24845c2f157d197475fb87b was verified
before editing. Static review performed; .NET compilation and ALL 33 new cases
are NOT_RUN in this environment. Existing tests were left unchanged.

Before merge run the Domain and Application/API tests, full project gates and
an independent review. Confirm invalid input cannot partially replace players.
The new test file is automatically included by the existing Domain.Tests SDK
project. No Node/TypeScript test substitutes for these C# tests.

## Integration

Independent of #67/#79/#80: this package changes the upstream byte decoder,
not either CSV codec. Test the combined import pipeline after integration.
Add STM-IE-011 to canonical BACKLOG as In Review with #85 and its actual PR;
CHANGELOG: BOM-marked Unicode imports decode strictly, unmarked legacy imports
retain their fallback. Do not mark Done before merge and green gates.
No dependency, version, generated product artifact or security-policy update.

Constructor contract checked 2026-10-01:
https://learn.microsoft.com/en-us/dotnet/api/system.text.unicodeencoding.-ctor
https://learn.microsoft.com/en-us/dotnet/api/system.text.utf32encoding.-ctor
