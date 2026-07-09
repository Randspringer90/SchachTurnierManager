---
name: internet-research
description: Internet-Recherche fuer aktuelle Informationen (Versionen, Breaking Changes, APIs, Doku) ueber die Websuche des jeweiligen KI-Tools; Ergebnisse mit Quelle und Abrufdatum dokumentieren.
---

# Skill: Internet-Research

## Wann

- Aktuelle Versionsstaende, Breaking Changes, CVEs, API-/Preisaenderungen.
- Alles, was juenger sein kann als der Wissensstand des Modells.

## Wie

1. Websuche des jeweiligen Tools nutzen (Claude Code: WebSearch/WebFetch;
   Codex: Browsing, falls aktiviert; sonst explizit nachfragen).
2. GitHub/Netz nur ueber den konfigurierten Proxy erreichen
   (Proxy-Host/-Port lokal/prozesslokal aus der Umgebung setzen,
   keine konkreten internen Adressen im oeffentlichen Repo).
3. Ergebnisse mit URL + Abrufdatum in den Lauf-Report uebernehmen.
4. Keine internen Namen, Pfade, Secrets oder Kundendaten in Suchanfragen.
