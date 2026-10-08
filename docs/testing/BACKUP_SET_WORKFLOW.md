# STM-UX-003: multi-tournament backup set and member recovery

The application entry links to /backup-set/index.html. Explicitly load the
available tournaments, select 1-10 and confirm that the exports contain private
data. The tool GETs native JSON exports sequentially and builds one unencrypted
stm-backup-set-1 JSON container. The downloadable link is only PREPARED; the
user must click it. No automatic download, import, overwrite or deletion occurs.

Each member stores the original UTF-8 JSON TEXT, byte length, SHA-256, basic
header counts and capture time. Parsing is used only for header checks; the
member is never serialized from a JavaScript number representation. Large
integer tokens, precise decimals, BOM, whitespace and line endings survive
member recovery. Limits: 2 MiB/member, 10 MiB total raw text, 24 MiB/container.
The metadata explicitly says atomicSnapshot=false because different tournaments
are read at different times. It is not a transactionally consistent DB backup.

The second workflow reads a selected container locally, validates its format,
allowed wrapper fields, every member ID/size/header and every SHA-256, and only
then offers native individual JSON downloads. A failed last member prevents
releasing the first. Unknown formats, duplicate tournament identities and
mismatching hashes are rejected. Cancellation invalidates pending results;
native File/WebCrypto work may still finish, but another UI operation cannot
start until the old one settles. Generated Blob URLs are revoked on reset.

This does NOT call the import endpoint or certify restore correctness. Native
headers are not full schema/chess-rule validation. JSON.parse duplicate-member
semantics apply; this tool is not an adversarial JSON integrity/signature
validator. Anyone able to rewrite the archive can also rewrite its checksums.
Use separate preflight/restore acceptance for native exports. The archive is
confidential and unencrypted; preserve and transport it accordingly. WebCrypto
needs an available secure-context implementation; no weak fallback is supplied.

Real File/WebCrypto tests cover multi-member roundtrip, exact byte preservation,
all-or-nothing errors, metadata/hash tampering, budgets, cancellation and manual
Blob links. No actual user backup was used. Full .NET restore/ASP.NET/browser
acceptance and independent review remain open. Canonical BACKLOG/CHANGELOG must
record this STM-UX-003 scope before merge without declaring Backup/Restore Done.
#77/#93/#94/#106 remain independent preflight/comparison tools, not dependencies.
