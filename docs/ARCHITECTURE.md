# Architektur

## Leitentscheidung

Die Anwendung ist API-first und Domain-first aufgebaut. Dadurch können später lokale Browser-Dashboards, PWA, Handy-App, externe Zuschaueransicht und Import-/Exportadapter dieselbe Fachlogik nutzen.

## Schichten

```text
WebApp -> WebApi -> Application -> Domain
                 -> Infrastructure
```

## Warum so?

- Pairing- und Wertungslogik ist kritisch und muss unabhängig testbar sein.
- WebApp soll austauschbar bleiben.
- SQLite/EF Core wird später ergänzt, ohne Domain zu verschmutzen.
- Swiss-/Chess-Results-Anbindungen werden Adapter, nicht Kernlogik.
