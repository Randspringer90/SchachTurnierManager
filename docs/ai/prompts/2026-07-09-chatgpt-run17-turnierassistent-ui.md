# Prompt — RUN-17 Turnierassistent im UI

Arbeite am SchachTurnierManager weiter. Führe RUN-17 aus: Turnierassistent im UI.

Ziele:

- Ein lokaler Assistent soll Turnierleitern bei der Formatwahl helfen.
- Keine KI-API, keine externen Requests, keine Secrets und keine automatischen destruktiven Aktionen.
- Eingaben: Teilnehmerzahl, Zeitfenster, Bretter, Szenario, gewertet ja/nein, Chess960/QR ja/nein.
- Ausgabe: Formatempfehlung, geplante Runden, Zeitbedarf, benötigte Bretter, Checklisten, Warnungen und Exportplan.
- Empfehlung soll Neuanlage/Einstellungen vorbefüllen können, aber bestehende Turniere nicht ungefragt ändern.
- Build/Test/Logging nach Projektstandard: ruhige Terminalausgabe, Details im Run-ZIP unter `D:\Temp`.

Scope bewusst klein halten: keine echte Chatbot-Anbindung, kein RAG, keine Cloud, keine Sync-Logik.
