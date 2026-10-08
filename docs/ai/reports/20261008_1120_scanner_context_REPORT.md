# SHA-gebundene Klassifikation gepruefter Scanner-Kontexte

Die sechs lexikalischen False-Positive-Klassen im bestehenden Integrationsstand
werden nicht unterdrueckt. 16 vollstaendige unveraenderliche Dateien wurden durch
zwei getrennte read-only KI-Reviewer an Source 745582e84a6d95df20c6a567c4531085c37de69f
geprueft. Die vertrauenswuerdige Base-Policy bindet diese Kontexte an exakten Pfad,
regulaeren Dateimodus, vorherigen und neuen Git-Blob sowie den Hash der jeweiligen
Regeldefinition. Jede Abweichung verwirft die Einstufung.

Das Online-Verfahren validiert auch bei bereits kompletten API-Patches die echten
Commit-/Tree-Identitaeten. Der Offline-Adapter entfernt fremde Bindungsbehauptungen.
Eindeutige Datei- und vollstaendige Hunk-Zuordnung ist erforderlich. Metadaten und
Header, andere Regeln, strukturelle Fehler, Bidi, Artefakte und Timeouts behalten
ihre bisherigen blockierenden Bedeutungen. Der gepruefte Inhaltsbefund bleibt HIGH
mit Pfad und Evidence-Hash; die exakte Owner-SHA-Ausfuehrungsfreigabe bleibt Pflicht.

Fokussierte Regression: 226 Kontext-Assertions, fuenf Online-Adapterfaelle sowie
bestehende Textpatch-, Engine- und Risikofalltests. Ergebnisse stehen SHA-gebunden
in lokaler Lauf-Evidence; nur wirklich ausgefuehrte Tests werden als PASS gewertet.
Keine fremde Codeausfuehrung oder Netzwerkanfragen in den synthetischen Tests.

CORE-KI: je ein Private-, Claude- und Local-Hilfsauftrag wurde eingereicht. Alle
stehen im nachgewiesenen Plattform-HOLD, bislang keine Provider-Turns. Busanfragen
zur sicheren Freigabe und Worker-Kapazitaet wurden gesendet. Das aendert weder die
STM-Merge-Freigabe noch die Integrationsqualitaet.

Offen bei Erstellung: finaler exakter KI-Review, Remote-CI und regulaerer Merge.
Kein fehlgeschlagener Check wird mit dem Approval-Bypass uebersprungen.
