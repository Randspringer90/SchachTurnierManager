# Schachwürfel / Chess960-Startstellungen

## Ziel

Für Freestyle-Würfelschach/Chess960 kann die Turnierleitung pro Runde die Startstellungen auswürfeln. Die Stellung wird am jeweiligen Brett gespeichert und ist dadurch im SQLite-Snapshot, JSON-Backup und in den Paarungs-/Runden-Exporten enthalten.

## Implementierter Stand

- Pro regulärem Brett einer bereits ausgelosten Runde wird eine eigene Chess960-Startstellung erzeugt.
- Bye-/spielfrei-Bretter erhalten keine Startstellung.
- Jede Stellung enthält:
  - weiße Grundreihe, z. B. `RNBQKBNR`
  - gespiegelte schwarze Grundreihe in Kleinbuchstaben
  - Chess960-Positionsnummer `0` bis `959`
  - Brett-Seed für Reproduzierbarkeit
- Vorhandene Startstellungen werden nur nach bewusster Bestätigung überschrieben.
- Ergebnisse werden beim Würfeln nicht verändert.
- Gesperrte oder geprüfte Runden können nicht mehr neu gewürfelt werden.
- Das Würfeln wird im Audit-Journal und zusätzlich im Runden-Audit protokolliert.

## Fachliche Regeln

Eine gültige Chess960-Grundreihe erfüllt:

- genau acht Figuren
- genau ein König, eine Dame, zwei Türme, zwei Läufer, zwei Springer
- die Läufer stehen auf verschiedenfarbigen Feldern
- der König steht zwischen den beiden Türmen
- Schwarz spiegelt Weiß

Die Nummerierung folgt der üblichen Scharnagl-/Chess960-Nummerierung von `0` bis `959`; die klassische Grundstellung `RNBQKBNR` ist Position `518`.

## Bedienung im Dashboard

1. Runde auslosen.
2. Im Bereich **Runden und Ergebnisse** bei der gewünschten Runde auf **🎲 Schachwürfel öffnen** klicken.
3. Das Schachwürfel-Popup zeigt einen sichtbaren 3D-Holzwürfel mit Schachfiguren-Seiten (König, Dame, Turm, Läufer, Springer, Bauer).
4. Auf **🎲 Würfeln** klicken: Der Würfel rollt/fliegt sichtbar über die Fläche und legt sich auf eine Ergebnisfigur. Anschließend wird pro regulärem Brett eine komplette, gültige Chess960-Startstellung erzeugt (Auslosung A) und am Brett gespeichert.
5. Das Popup listet pro Brett Paarung, Startstellung (Weiß/Schwarz gespiegelt), Positionsnummer (SP) und Seed.
6. Bei Bedarf **Rundenblatt drucken** öffnen. Die Startstellungen stehen im Rundenblatt und in den Paarungs-CSV-Dateien.
7. Wenn bereits Stellungen vorhanden sind, fragt das Dashboard vor dem **Neu würfeln** nach. Gesperrte/geprüfte Runden lassen sich nicht würfeln.

Die Animation ist rein visuell; die tatsächlich gespeicherte Stellung erzeugt weiterhin der validierte `Chess960PositionService` (Läufer verschiedenfarbig, König zwischen den Türmen, Schwarz spiegelt Weiß). Bei Reduced-Motion-Einstellung läuft die Animation verkürzt.

## Gleiche Stellung für alle Bretter vs. pro Brett

Aktuell ist **pro Brett eine eigene Stellung** implementiert. Das passt für Freestyle-Würfelschach, wenn jedes Brett eigenständig ausgewürfelt werden soll. Eine spätere Option "eine Stellung für alle Bretter der Runde" ist möglich, aber nicht Teil dieses stabilisierten Bergfest-Standes.

## Roadmap

- QR-/Handy-Link für Spieler ist bewusst nicht enthalten.
- Optionaler Druckzettel nur für Startstellungen kann später ergänzt werden.
- Eine UI-Option für "eine Stellung für alle Bretter" kann später ergänzt werden, falls das Turnierformat das verlangt.
