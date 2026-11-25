# STM-REV-003: unabhaengige Vertrauenswurzel

Stand: 2026-10-28. Dies ist ein Arbeitsentwurf mit verifizierten Konfigurationsdaten, keine
Ausfuehrungs-, Owner- oder Mergefreigabe. Serverseitige Aktivierung steht aus.

## Nachgewiesener Ausgangspunkt

Die Live-Abfrage des kanonischen Public-Repositories ergibt einen persoenlichen
Owner (`User`), Repository-ID 1261927771 und `development` als Standardbranch.
Das aktive Ruleset 18830718 verlangt PR-/Codeowner-Review und die sieben Kontexte
`pr-static-security`, `security-gate`, `agent-integrity`, `build-test`,
`frontend`, `diff-check` und `branch-policy`. Eine unabhaengig festgelegte
Workflowdefinition ist in den abgerufenen Branchregeln nicht enthalten.

Die aktuellen Workflows pruefen mit Base-Code, ihr eigener Jobgraph stammt jedoch
aus der PR-veraenderbaren Workflowdefinition. Derselbe Kontextname kann in einer
anderen Definition vorkommen. Kontextnamen und die GitHub-Actions-App allein
belegen deshalb keine bestimmte Ausfuehrungsreihenfolge. Auch ein lokal gruener
Readiness-Test kann diese serverseitige Luecke nicht schliessen.

GitHub dokumentiert verpflichtende Ruleset-Workflows auf Organisations-/Enterprise-
Ebene. Diese Moeglichkeit wird fuer das persoenliche Repository nicht als vorhanden
unterstellt. [GitHub: Ruleset-Workflows](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

## Vorbereiteter Weg im bestehenden Trustmodell

Eine unabhaengig betriebene, vom Owner genehmigte GitHub App muss einen eigenen
statischen Status erzeugen. Ihre Definition und Berechtigungen liegen ausserhalb
des zu pruefenden PR-Heads. Der bestehende zentrale CORE-KI-Weg kann nur verwendet
werden, wenn diese App-Bindung, Admission und Berechtigung tatsaechlich bestaetigt
sind. Es wird kein zweiter Scheduler, Dienst oder Provider-Ausweichweg angelegt.

Der Vertrag fuer den vorhandenen beziehungsweise vom Owner bereitzustellenden
Pruefer lautet:

1. Repository-ID, PR-Nummer, aktuellen Base-/Head-SHA und zugelassene Schutzpolicy
   aus verifizierten Quellen lesen; Metadaten und Patch bleiben T4.
2. Den statischen Pruefer und seine Policy aus einer freigegebenen, unveraenderlichen
   Base beziehen. Kein Restore, Build, Test oder Lifecycle-Code des PR-Heads.
3. Vollstaendige Datei-/Blob-/Patchbindung pruefen. Ein kritischer oder unverifizierter
   Befund bleibt blockierend; erforderliche echte Owner-Entscheidungen nicht ersetzen.
4. Einen eigenstaendigen Status, zum Beispiel `stm-independent-static-review`, mit
   genau dieser App-Identitaet am aktuellen Head berichten. Base-, Policy- und
   Reviewdrift entwerten ihn; die strikte Base-Bindung bleibt erforderlich.
5. Das bestehende Ruleset muss diesen zusaetzlichen Kontext **mit der konkreten
   App-ID als Quelle** verlangen. Alle sieben bisherigen Checks, Codeowner-Review
   und offene Konversationen bleiben verbindlich. GitHub kann die Herkunft eines
   erforderlichen Checks an eine App binden.
   [GitHub: Check-Herkunft](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks?apiVersion=2022-11-28).

Die generische GitHub-Actions-App ist dafuer keine unabhaengige Identitaet:
andere PR-Workflows benutzen dieselbe App. Ein Label, ein AI-Reviewtext oder ein
Kommentar des Agenten ist ebenfalls kein Ersatz fuer die erforderliche Freigabe.

## Konkrete Aktivierungs- und Abnahmegates

- Owner bestaetigt eine bereits vorhandene, zulaessige App-/Prueferbindung oder
  entscheidet separat ueber deren Bereitstellung. Keine Zugangsdaten in Quellen,
  Reports oder Workerpaketen; keine neuen Kosten aus diesem Entwurf ableiten.
- App-ID, kontrollierte Pruefer-/Policyversion und SHA-Bindung unabhaengig reviewen.
- Serverseitige Regel zusaetzlich einrichten und die wirksamen Regeln erneut lesen.
  Dieser Lauf hat keine Regel oder Ausnahme angelegt oder veraendert.
- Mit synthetischen PRs belegen: gleicher Kontext von falscher App reicht nicht;
  ausgelassener Pruefer reicht nicht; neuer Head oder neue Base verlangt neuen
  Nachweis; kritische Payload startet keine Produktjobs. Erst nach gueltiger
  statischer Freigabe duerfen die bestehenden Produktpruefungen anlaufen.
- Die letzte Eigenschaft braucht eine unabhaengige Aufnahme-/Ausfuehrungskontrolle,
  nicht nur ein Mergeverbot. Ein zusaetzlicher Status allein verhindert den Start
  eines manipulierten PR-Workflows noch nicht. Die Plattform muss den kontrollierten
  Ausfuehrungsweg durchsetzen; bis zu diesem Nachweis bleibt STM-REV-003 offen.

Ein Wechsel auf privilegierte PR-Ausfuehrung, fremder Checkout mit erweiterten
Rechten, Abschalten bestehender Checks oder ein stellvertretender Approvalmarker
ist nicht Teil dieses Entwurfs. Der Restgate ist administrativ und technisch;
lokale Workflowaenderungen koennen ihn nicht selbst freigeben.
