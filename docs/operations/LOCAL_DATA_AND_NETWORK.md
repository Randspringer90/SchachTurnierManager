# Lokale Daten, Offline-Ergebnisse und FIDE-Suche

Stand2026-10-28: lokaler Integrationskandidat, noch nicht nach development übernommen.

## Ergebnisqueue

Die Ergebniseingabe kann einen Auftrag vor dem Versand dauerhaft in diesem Browser
ablegen. Die Queue enthält pseudonyme Turnier-/Paarungskennungen und Vorbedingungen,
keine Namen oder Freitexte. Sie meldet lokale Speicherung getrennt von einer
Serverbestätigung. Nach Wiederverbindung lässt sich die Queue sichtbar synchronisieren.
Eine verlorene Erfolgsantwort erzeugt bei Wiederholung desselben Auftrags keine zweite
Ergebnismutation. Zurücksetzen/Restore und geänderte Paarungen oder Ergebnisse lösen
einen Konflikt aus; die Queue überschreibt solche Änderungen nicht still.

Bei Konflikten den aktuellen Serverstand vergleichen. Das bestätigte Entfernen eines
Queueeintrags entfernt nur die lokale Kopie und ruft keinen bereits verarbeiteten
Serverauftrag zurück. Browserdaten nicht löschen, solange ungesendete Aufträge benötigt werden.
Andere Mutationen, etwa Teilnehmeränderungen, sind damit nicht automatisch offline verfügbar.

## FIDE-Namenssuche

Im Teilnehmerbereich eine selbst gewählte, entpackte offizielle FIDE-Standard-TXT-Liste
laden. Unterstützt werden die Spalten ID Number, Name, Fed und SRtng/STD; kein ZIP,
XML oder Rapid-only-Format. Höchstens256MiB, zwei Millionen Zeilen und1024Zeichen je
Zeile; ungültige Daten ersetzen keine gültige Liste. Der Import endet spätestens
nach90Sekunden, die lokale Suche nach10Sekunden. Ergebnisse sind auf50begrenzt.

Die Liste liegt lokal im App-Datenverzeichnis unter `fide-cache`, unabhängig vom
Repository. Suchergebnisse werden höchstens24Stunden zwischengespeichert; ein älterer
Listenimport bleibt offline nutzbar und wird als solcher angezeigt. Importzeit und
Veröffentlichungsdatum der Ratingliste sind unterschiedliche Angaben. Quelle und
Listenstand vor Übernahme prüfen. Namen und Listen werden nicht an FIDE übertragen;
es gibt keinen Hintergrunddownload. [Offizielle Downloads](https://ratings.fide.com/download_lists.phtml).

Mehrdeutige Treffer einzeln prüfen. Zielteilnehmer und jedes zu übernehmende Feld
ausdrücklich auswählen und anschließend bestätigen. Abbrechen ändert keine
Teilnehmerdaten. Nicht ausgewählte lokale Felder bleiben erhalten. Ein inzwischen
geänderter Zielspieler verlangt eine neue Vorschau. Die bestätigte Übernahme wird
mit den geänderten Feldern im lokalen Audit protokolliert.

Der vorhandene direkte FIDE-ID-Abruf bleibt getrennt: nur ausdrücklich angefragte IDs,
höchstens ein gleichzeitiger Abruf und ein Start jeSekunde, zehnSekunden Frist,
512KiB Antwortgrenze sowie Backoff bei429/5xx. Die Namenssuche nutzt diese fragile
HTML-Schnittstelle nicht. Tests verwenden synthetische Listen und gemockte Antworten.

## HTTP und Entwicklung

Desktop-/Portable- und reguläre Entwicklungsstarts bleiben auf Loopback. Auch der
Vite-Devserver bindet an127.0.0.1; sein API-Proxy darf nicht durch einen ungeschützten
Wildcard-Listener im LAN angeboten werden. Ein manueller Wechsel auf alle Interfaces
umgeht diese sichere Vorgabe. Der frühere anonyme Handyzugriff über den Devserver
ist deshalb kein aktuell freigegebener LAN-Betriebsweg.

Die API prüft Host und Origin auf dem Server. Lokale Browser sowie lokale Prozesse
ohne Origin bleiben nutzbar; lokale Prozesse werden als vertrauenswürdig vorausgesetzt.
Das ist keine Isolation zwischen verschiedenen OS-Benutzern. Fremde Proxies oder
Mehrbenutzerhosting benötigen eine gesonderte Sicherheitsabnahme.

Nicht lokale API-Clients benötigen eine TLS-Verbindung, explizit konfigurierte
`SchachTurnierManager:AllowedLanHosts` und ein starkes Laufzeitcredential im Header
`X-STM-Lan-Token`. Das Credential ausschließlich aus geschütztem lokalen Secret-/
Prozess-Environment bereitstellen (`SchachTurnierManager__LanAccessToken`), niemals
in Quellen, URLs, Logs oder veröffentlichte Konfiguration schreiben. Diese Vorbereitung
ersetzt keine echte LAN-/TLS-/Geräteabnahme und keine unterstützte Credential-UX
des Android-/Browserclients. Kein TLS- oder Signierschlüssel wurde hier bereitgestellt.

## Teilfehler bei gelesenen Turnierprojektionen

Schlägt eine der sechs abgeleiteten Ansichten fehl, zeigt die Oberfläche einen
eigenen Fehlerstatus und eine Wiederholung an. Der bestehende gesunde Backend-
Pollingzyklus lädt ausschließlich fehlgeschlagene Projektionen erneut; fertige und
laufende Abrufe werden dabei nicht neu gestartet. Die manuelle Wiederholung ist
bereits vor dem nächsten React-Render gegen Doppelklicks geschützt. Ungesendete
Teilnehmereingaben bleiben erhalten. Dies ist eine Wiederholung lesender API-
Anfragen und verändert weder Turnierdaten noch Audit-Einträge.
