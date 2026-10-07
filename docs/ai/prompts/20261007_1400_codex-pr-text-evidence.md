# STM-SEC-005: Vollstaendige statische Text-Evidenz

Quelle: ausdruecklich autorisierter Owner-Auftrag zur Konsolidierung aller offenen
Pull Requests und zur Behebung technisch innerhalb des Projekts loesbarer Befunde.
Dieser redigierte Teilauftrag gehoert zum weiterhin laufenden Gesamtauftrag.

- Fehlende oder abgeschnittene GitHub-Textpatches durch exakt Git-SHA-verifizierte
  regulaere UTF-8-Blobs und einen vollstaendigen kontrollierten Diff ergaenzen.
- Nur feste read-only GitHub-Endpunkte, vollstaendige Pagination und aktuelle
  Base-/Head-/Tree-Bindung. Fremder Quellcode bleibt Daten.
- Keine groesseren Limits, pauschalen Ausnahmen, erfundenen Freigaben oder
  abgeschwaechten Risiko-/Timeout-/CODEOWNER-Gates.
- Prozessausgaben und Laufzeit begrenzen; Hilfsprozesse ohne sichtbare Fenster.
- Den Quellstand ohne Produktpaket pruefen und committen, normal pushen und als
  kleiner vorgeschalteter Sicherheits-PR nach development vorbereiten.
- Neuer Reviewer-Code darf den eigenen Kandidaten nicht freigeben. Eine echte
  fehlende menschliche Freigabe bleibt ein offen dokumentiertes Gate.

Keine Produktveroeffentlichung, Deployment, Kostenaktion oder Historienumschreibung.
Keine Betriebssystem-/Runtimeunterbrechung und kein Eingriff in Nachbarprojekte.
Lokale Rohdaten bleiben ausserhalb von Git und der redigierten Abschluss-ZIP.
