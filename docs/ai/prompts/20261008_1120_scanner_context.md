# Owner-Auftrag: bestehenden Integrationslauf abschliessen

Quelle: fortgesetzter Owner-Masterprompt vom 2026-10-08; bisherige gepruefte
Integrationsarbeit wiederverwenden. Vollstaendiger redigierter Auftrag steht in
20261008_1030_final-integration.md. Keine neue Funktionsentwicklung erforderlich.

Alle CI-Gates muessen erfolgreich bleiben. Erforderlicher Folgefix: sechs
lexikalische Klassen melden harmlose bereits unabhaengig gepruefte Kontexte als
kritisch. Keine pauschale Ausnahme und kein Ueberspringen fehlgeschlagener Checks.
Exakte unveraenderliche Datei-/Modus-/Blob-/Regelbindung aus vertrauenswuerdiger
Base-Policy pruefen; Findings mit HIGH und Owner-SHA-Ausfuehrungsfreigabe erhalten.
Unbekannte, veraenderte, unvollstaendige, strukturelle oder Offline-Evidenz bleibt
blockiert. Scanner-Folge-PR regulär testen, KI-reviewen und ueber grüne CI integrieren.

Owner-Randnotiz: zusaetzliche CORE-KI-Profile fuer begrenzte Hilfsaufgaben nutzen und
Kapazitaeten per Plattformbus mit laufender CORE-KI-Session abstimmen. Plattform-
Holds nicht kuenstlich umgehen. Keine zusaetzlichen sichtbaren Fenster.
