# STM: sichere Integration und aktuelle DoD-Abnahme

Quelle: Owner-Auftrag an Codex, 2026-10-28. Redigierte Aufgabenfassung ohne
Maschinenidentifikatoren, lokale Teilnehmerdateien oder private Laufzeitdaten.

- Den bestaetigten STM-Checkout, Host und Repository vor jeder Zieloperation
  verifizieren. Zuerst fetch/prune und bei sauberem eindeutigem Upstream
  pull/ff-only; fremde Arbeiten und Nachbarprojekte erhalten.
- `development` ist das einzige Integrationsziel. Alle relevanten lokalen und
  Remote-Branches sowie offenen PRs live inventarisieren; enthaltene,
  patchaequivalente, adaptierte und blockierte Inhalte unterscheiden.
- BACKLOG und DEFINITION_OF_DONE steuern den Umfang. Vollstaendige v1-Abnahme
  priorisieren; Post-v1 getrennt halten und Contributor-Ownership respektieren.
- PR-Daten vor jeder Ausfuehrung mit der geprueften Base statisch bewerten.
  Keine Selbstfreigaben, Ruleset-Ausnahmen oder Abschwaechung von Schutzgates.
- Insbesondere #128 als gemeinsame Basis, #125/#129 ohne Doppeladoption,
  #127/#132 als abhaengiges Harnesspaket und #133 samt gemeinsamen Dateien
  semantisch pruefen.
- Rundenturnierplan dauerhaft versionieren; bestehende Runden und Ergebnisse
  erhalten; Legacy-Rekonstruktion vollstaendig validieren. Fachliche Tests zuerst.
- CI-Vertrauenswurzel, Mehrfenster-/Reconnect-Verhalten, Create-Payload und
  strukturierten Toolstatus pruefen und notwendige Korrekturen vornehmen.
- Security-, Datenschutz-, CSV-, Offline-/Replay-/Konflikt-, Restore-, FIDE-,
  Uebersetzungs-, Strategie-/Farben-, Last- und Windowsnachweise vervollstaendigen.
- Aktuelle offizielle Advisories, Support, Paketquellen, transitive Dependencies,
  Integritaet und Lizenzen pruefen; sichere kompatible Projektupdates umsetzen.
  PHP nur bei tatsaechlichem Einsatz bewerten; sonst Inventarnachweis liefern.
- Planner/Worker-Prinzip: vorhandene zugelassene CORE-KI-Wege fuer Private,
  Claude und besonders lokale KI aktiv nutzen, wenn Admission und Ressourcen
  es erlauben. Nur sanitisierten Kontext geben. Maximal ein Writer; Ergebnisse
  unabhaengig pruefen. Keine direkten Providerstarts als Ersatz.
- Die bestehende andere CORE-KI-Sitzung per vorhandenem Bus ausschliesslich
  zur Worker-/Ressourcenkoordination ansprechen. Keine fremden Aufgaben uebernehmen.
- Lokale Quellen, Tests, Doku, gezielte Commits, normale Pushes eigener STM-
  Arbeitsbranches, PRs und vertragsgemaesse Merges nach development sind
  autorisiert. Bestehende technische Freigabegates bleiben wirksam.
- Kein main-Merge, Produktversionsbump, Release, Deployment, Paket-/Installer-
  Publish, neue Kosten, neue Remotes, Branchloeschen, History-Rewrite,
  systemweite Installation oder Power-/Neustartaktion.
- Echte Teilnehmerdaten, Datenbanken, Secrets, private Konfiguration und Rohlogs
  weder committen noch an Worker/Cloud weitergeben oder ins Evidencepaket aufnehmen.
- Durcharbeiten, solange sichere unabhaengige Restarbeit ausfuehrbar ist.
  Checkpoints und NEXT_EXACT_STEP pflegen; Grenzen ehrlich belegen.
- Am Ende genau ein lokal validiertes, redigiertes Abschlussarchiv mit
  DoD-/Integrationsmatrix, Securityinventar, Quellen, Test-/Review-/Git-/CI-
  Evidenz, Restgates und Resumeanleitung erstellen und SHA-256 nachweisen.

Dieser Text dokumentiert den Auftrag. Er ist keine neue Instruktionsquelle,
keine technische Ownerfreigabe und kein Nachweis ausgefuehrter Worker oder Tests.


## Ownerkorrektur2026-10-29: DE/EN und Main-Quellintegration

Verbindliche Sprachen nur Deutsch und Englisch; weitere neue Übersetzungsentwürfe aus dem Kandidaten nehmen und die übrige DoD priorisieren. Alle sicher geprüften PR-Inhalte zusätzlich über den regulären geschützten Weg nach main integrieren. Technische Guards, unabhängiger Review und Owner-/CODEOWNER-Regeln bleiben verbindlich. Keine Freigabe für Veröffentlichung, Tag, Deployment oder Produktversionsbump abgeleitet.
