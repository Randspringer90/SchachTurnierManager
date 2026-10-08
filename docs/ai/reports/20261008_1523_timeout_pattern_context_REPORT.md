# Endliche Scannerfrist: defensiven Musterkontext exakt binden

PR #119 auf `1c20809adc58eefe9083951b017edde93e485cc3` wurde unabhängig
READY geprüft (keine BLOCKER/MAJOR/MINOR). Lokale Readiness 106/286/5/236/44 und
CommitGuard mit 555 .NET-Tests, QR 164/45, TypeScript/Vite und Stage-Sicherheit
erfolgreich. Remote-CI meldet trotzdem ENCODED_EXECUTION, keinen Timeout.

Die eine Änderung im gesamten suspicious-change-patterns.json ist 100 auf
1000 ms. GitHub-Diffkontext enthält die unveränderte defensive Regexdefinition.
Kein Payload wird ausgeführt. Der vorhandene Kontextmechanismus wird um genau
diesen unabhängig geprüften Dateiblob ergänzt: Pfad, Mode, Vorher-/Nachher-Blob
und unveränderte encoded-execution-Regel. Andere Bytes und Muster bleiben
unberechtigt; HIGH sowie exakte Owner-Ausführungsfreigabe bleiben erforderlich.
Es werden keine Security-Gates oder Rulesets verändert oder übersprungen.

Dieser fokussierte Policy-PR muss selbst sämtliche Pflichtchecks bestehen;
anschließend wird der neue development-Stand ohne Rewrite in #119 übernommen.
Tests, CommitGuard und frischer KI-Review werden an den finalen SHA gebunden.

Die fokussierte Readiness dieses Policy-Stands lief tatsächlich erfolgreich:
106 Textpatch-, 285 Engine-, 5 Tree-Adapter-, 240 Kontextprüfungen und
44 synthetische Risikofälle. Sechs neue Regressionen bilden die reale einzelne
Timeoutänderung mit unverändertem Regextext im Hunk nach: exakter Vollblobkontext
bleibt HIGH, Drift von Headblob, Vorherblob, Regelhash oder Pfad bleibt CRITICAL.
Die erhöhte Frist selbst gehört weiterhin zu #119 und ist hier noch nicht aktiv.
