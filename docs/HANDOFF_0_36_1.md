# Handoff 0.36.1 - Audit-Journal Query Testfix

## Ziel

v0.36.1 behebt einen Buildfehler aus v0.36.0 in den neuen Audit-Journal-Query-Tests.

## Problem

`tests/SchachTurnierManager.Domain.Tests/AuditJournalQueryServiceTests.cs` verwendete `[Fact]`, enthielt aber kein `using Xunit;`. Dadurch scheiterte `dotnet build` mit `CS0246` für `Fact`/`FactAttribute`.

## Änderung

- `using Xunit;` in `AuditJournalQueryServiceTests.cs` ergänzt.
- Versionen auf `0.36.1` gesetzt.
- Changelog ergänzt.
- Release-Gate bleibt Pflicht.

## Erwartete Nachkontrolle

- `dotnet build` grün
- `dotnet test` ungefähr 86/86 grün
- `npm run build` grün
- Portable-ZIP `SchachTurnierManager_Portable_0.36.1.zip`

## Hinweis

Fachlich ändert v0.36.1 nichts am Query-Service. Es ist nur ein Test-Build-Fix.
