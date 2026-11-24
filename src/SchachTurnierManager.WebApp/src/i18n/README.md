# i18n – Mehrsprachigkeit der WebApp

Verbindlicher Fertigstellungsumfang laut Ownerkorrektur vom2026-10-29: **Deutsch und Englisch**. Beide Kataloge haben538 explizite Schlüssel. Zusätzliche in diesem Lauf erzeugte Übersetzungsentwürfe sind aus dem Integrationskandidaten entfernt und nur lokal erhalten.

Das Modul arbeitet ohne weitere i18n-Abhängigkeit. de.ts ist Schlüsselquelle; Messages wird daraus abgeleitet. en.ts enthält den englischen Katalog. I18nProvider, useI18n und LanguageSwitcher liegen in index.tsx. Sprachwahl wird lokal unter stm.language gespeichert; fehlende Werte fallen auf Englisch und dann Deutsch zurück. Dokumentlang und -richtung folgen der Auswahl, Parameter werden durch t interpoliert.

Die16 bereits vorhandenen zusätzlichen Vorschaukataloge bleiben auf ihrem unveränderten Ausgangsstand. Sie sind kein zusätzlicher Fertigstellungsauftrag; fehlende Einträge in diesen Katalogen sind keine fehlenden DE/EN-Einträge.

DE/EN decken Einstieg, Kernnavigation, Turnierverwaltung, Importkontrollen, Assistentenpläne, Auditlabels, acht lokale Hilfethemen sowie Chess960-/QR-Dialoge ab. Restliche Produkt-/Backendtexte und einzelne Nebenwerkzeuge sind für die finale DE/EN-Abnahme zu prüfen. Schlüsselparität ist kein vollständiger Ablauf- oder Sprachreview.

Neue Produkttexte zuerst als Schlüssel in de.ts ergänzen und en.ts gleichzeitig pflegen. Fachlich erzeugte Namen, Positionen, IDs, Auditbelege und Benutzerdaten werden nicht durch Übersetzung verändert. Build-/Katalogtests und echte DE/EN-Browserfälle gehören zum betroffenen Nachweis.
