# Scanner: native Regex-Zeitgrenze und Verwaltungsaufwand getrennt begrenzen

Der große Integrationsstand bleibt unveraendert. Lokal liefert der vertrauenswuerdige
Scanner 236 Findings und OWNER_REVIEW_REQUIRED. Bei identischem Head/Base lieferte
GitHub wiederholt in einzelnen Jobs 237 Findings und BLOCKED_UNVERIFIED; andere
Jobs bestanden nach der exakten KI-Ausfuehrungsfreigabe. Der zusaetzliche Code ist
in alten Logs nicht enthalten und wird nicht als gesichert behauptet.

Der Quellreview zeigt einen eigenstaendigen Budgetfehler: Eine neu eingefuehrte
100-ms-Stoppuhr zaehlt auch Regex-Konstruktion, JIT, PowerShell-Enumeration,
Hunk-Bereichszuordnung und Scheduling. Diese Arbeit ist nicht die native
Regex-Pruefung. Sie erhaelt jetzt ein eigenes begrenztes Zwei-Sekunden-Budget mit
periodischer Kontrolle. Die native Grenze von 100 ms pro Regex-Aufruf und die
Grenze von 10.000 Treffern bleiben erhalten. Jeder echte Timeout, jede Budget-
ueberschreitung und jeder nicht attestierbare Treffer bleiben CRITICAL.

234 Kontext-Assertions enthalten einen vollstaendigen synthetischen Grosspatch mit
100.000 gueltigen Hunks (3,49 MB) und zwei
spaeten harmlosen Treffern prueft Bereichszuordnung und unveraenderte Findings.
Native Timeout-, Mengenlimit-, Header-, Struktur- und Driftregressionen bleiben
Teil der fokussierten Suite. Historische RED/GREEN-Ergebnisse werden in lokaler
Evidence festgehalten; ein erster schneller Rechnerlauf reproduzierte den alten
Fehler nicht. Auch der volle Grosspatch bestand historisch und aktuell; eine
RED-Reproduktion wird ausdruecklich nicht behauptet.

Die Scannerdiagnose gibt zukuenftig nur validierte blockierende Finding-Codes aus,
keine Pfade, Inhalte, private Daten oder Secrets. So laesst sich ein CI-Fehler
gezielt auswerten, ohne untrusted Inhalte zu veroeffentlichen.

Offen bei Erstellung: finaler exakter SHA-Review, CI und regulaere Uebernahme.
Kein Bypass fuer fehlgeschlagene Checks. CORE-KI-Hilfsauftraege bleiben nachgewiesen
im HOLD; Nachrichten an beide als aktiv registrierten Busrollen sind ausstehend.
