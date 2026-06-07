# Architektur

## Leitentscheidung

Die Anwendung ist API-first und Domain-first aufgebaut. Dadurch können später lokale Browser-Dashboards, PWA, Handy-App, externe Zuschaueransicht und Import-/Exportadapter dieselbe Fachlogik nutzen.

## Schichten

```text
WebApp -> WebApi -> Application -> Domain
                 -> Infrastructure
```

## Persistenz

Version 0.2 speichert Turniere über EF Core + SQLite als JSON-Snapshots in einer lokalen Datenbank. Das ist bewusst pragmatisch: Das Domainmodell kann sich in der frühen Phase noch schnell ändern, ohne dass wir sofort umfangreiche Migrationen für jede Fachmodelländerung brauchen.

Standardpfad:

```text
%LOCALAPPDATA%\SchachTurnierManager\SchachTurnierManager.sqlite
```

Später kann aus den Snapshots ein normalisiertes relationales Modell entstehen, wenn Import/Export, Historie und parallele Bearbeitung stabiler spezifiziert sind.

## Warum so?

- Pairing- und Wertungslogik ist kritisch und muss unabhängig testbar sein.
- WebApp soll austauschbar bleiben.
- SQLite/EF Core ist in `Infrastructure` isoliert.
- Swiss-/Chess-Results-Anbindungen werden Adapter, nicht Kernlogik.
- Manuelle Änderungen sollen später im Audit sichtbar sein.
