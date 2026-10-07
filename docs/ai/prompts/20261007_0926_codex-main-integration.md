# Auftrag: vollständige PR-Konsolidierung und aktuelles KI-Harness

Quelle: aktueller Owner-Auftrag, 2026-10-07. Lokale Maschinenpfade sind redigiert.

Alle offenen Pull Requests von Randspringer90/SchachTurnierManager live und vollständig inventarisieren, fachlich und technisch reviewen, Überschneidungen erkennen, Befunde korrigieren und sämtliche sinnvollen vollständigen Inhalte zunächst über development und danach regulär nach main übernehmen. Fehlende Funktionen und Tests dürfen bei Konflikten nicht entfernt werden. Der kanonische Hauptcheckout ist der einzige Arbeitscheckout; das unabhängige Nachbarprojekt ist vollständig ausgeschlossen.

Lokale Änderungen, Commits, normale Pushes, PRs, reguläre Merges und CI-Prüfung sind ausdrücklich autorisiert. Kein Force-Push, History-Rewrite, Branchschutz-Bypass, Release, Deployment, Kostenaufruf, Produktartefakt-Update oder Workstation-Neustart. Drei konkret benannte historische STM-Checkouts dürfen ausschließlich nach vollständigem Integrations-, Redundanz-, Prozess- und Pfadnachweis am Ende bereinigt werden.

Fokussierte und vollständige .NET-/Node-/Frontend-/QR-/Übersetzungs-/PWA-/Offline-Tests, TypeScript, Produktionsbuild, Security- und Repository-Gates sowie relevante headless Browser-Smokes prüfen. Nach semantischen Änderungen erneut testen und reviewen. Getrennter finaler read-only Review des tatsächlichen finalen Stands mit READY erforderlich. GitHub-Rulesets und CODEOWNERS bleiben verbindlich; fehlende menschliche Freigabe konkret als BLOCKED melden, nicht umgehen.

PRs ausschließlich regulär mergen oder bei vollständigem konkretem Main-Inhaltsnachweis als superseded schließen. Ziel: keine offenen PRs, akzeptierte Inhalte nachweislich in main, kanonischer Checkout sauber und synchron. Fortschritt anhand deduplizierter BACKLOG-Aufgaben und Definition of Done statt PR-Anzahl auswerten. Genau ein finales lokales Ergebnis-ZIP mit redigierten Berichten, Checkpoint, Integrationsmatrix, Test-/Review-/Git-/Cleanup-Nachweisen und validiertem Hashmanifest erzeugen.

Owner-Ergänzungen während des Auftrags: aktiv im Hauptverzeichnis arbeiten, PRs bei Problemen verbessern und integrieren; aktuelle Codex-/Claude-Modelle im projektspezifischen KI-Harness prüfen und dynamisches Routing ergänzen, falls es fehlt. Vorhandene Systeme semantisch aktualisieren, keine Doppelimplementierung.

Weitere Owner-Freigabe: begruendete Verbesserungen an Projektregeln und Architektur
sind erlaubt; Ergebnisse und Begruendungen muessen im Abschluss-ZIP nachvollziehbar
sein. Waehrend paralleler Plattformarbeiten den vorhandenen CoreKI-Bus beachten
und koordinieren. Bestehende Grenzen gegen Profilwechsel, Kosten, Artefaktupdates,
History-Rewrite und Branchschutz-Bypass bleiben erhalten.
