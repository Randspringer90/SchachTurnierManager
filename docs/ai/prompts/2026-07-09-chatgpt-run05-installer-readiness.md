# Prompt 2026-07-09 – ChatGPT: RUN-05 Installer-Readiness

Auftrag aus dem Chat:

- Nach grüner 0.42.6-Basis am SchachTurnierManager weiterarbeiten und sich an die Roadmap halten.
- Als nächster sinnvoller Schritt RUN-05: Installer/Setup-EXE näher an Release-Reife bringen.
- Keine Downloads, Installationen, Releases, Pushes oder Kostenaktionen ohne Freigabe.
- Terminalausgaben künftig kurz halten; Details in Run-Ordner unter `D:\Temp`, am Ende ein ZIP zum Upload.
- Logging und Dokumentation ordentlich pflegen.

Umsetzung:

- RUN-05 nicht als blinden lokalen Installer-Build erzwingen, sondern als reproduzierbaren Readiness-Lauf umsetzen.
- Falls Inno Setup nicht installiert ist, sauber als Blocker dokumentieren; falls vorhanden, Installer bauen und Hash/Manifest erzeugen.
- Bestehendes Desktop-/Portable-Paket beibehalten.
