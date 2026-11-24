# Lizenz- und Notice-Vorbereitung – 2026-10-28

Kein rechtlicher Abschluss und keine Distributionsfreigabe. Das Projekt besitzt
weiterhin keine Root-Lizenz. Die vorhandene Ownerentscheidung in
`docs/submission/LICENSE_DECISION.md` bleibt verbindlich; keine fremden Beiträge
werden stillschweigend neu lizenziert.

Der Bestand unterscheidet36 aktive NuGet-App-Pakete, zwei tatsächlich ausgelieferte
Frameworkpacks, ein nur erworbenes Frameworkpack und fünf alte Cacheversionen.
Alle44 erworbenen Cachepakete wurden gegen Ursprung/Signatur geprüft; aktive
Contenthashes passen zu den Locks. Das npm-Lock enthält49 Einträge einschließlich
der Projektwurzel, also48 externe Pakete.23 davon sind im aktuellen Windows-
Testbestand installiert; optionale andere Plattformziele wurden nicht zusätzlich
heruntergeladen. Der reine Paketbestand ist keine Aussage, dass alle Pakete in der
Anwendung ausgeliefert werden.

Vorbereitet sind Metadaten pro Version und30 verfügbare Lizenz-/Noticetexte aus
geprüften Paketen samt SHA-256: sieben NuGet-Pakete und22 installierte npm-Pakete
enthalten passende eigenständige Textdateien. Die lokalen Evidence-Dateien
`third-party-license-evidence-20261029.json` und `third-party-license-texts-20261029/` dokumentieren
Quelle, Version und Textbindung. Viele NuGet-Pakete deklarieren nur einen SPDX-
Ausdruck; fehlende eigenständige Dateien beweisen allein keinen Lizenzverstoß.

Offen vor einer später autorisierten Distribution:

- Root-Lizenz und erforderliche Contributor-Rechte ausdrücklich klären.
- Historische Lizenzreferenz von `xunit.abstractions2.0.3` unveränderlich belegen;
  aktuelle Dokumente oder eine bewegliche URL ersetzen keine Versionsbindung.
- Tatsächlich ausgelieferte Dateien den benötigten Copyright-/Notice-/gegebenenfalls
  Sourcepflichten zuordnen und deren Aufnahme in signierte Pakete abnehmen.
- Kein Herstellertext und keine deklarierte SPDX-ID wird hier als anwaltliche
  Freigabe, Rechteübertragung oder gewählte Produktlizenz ausgegeben.

Nachprüfung 2026-10-29: Der offizielle Tag `2.0.3` verweist auf Commit
`489a2b3949a9ae8587201a22a8ecfc1d791fa1f3`. Dessen vollständig gelesener Gitbaum
enthält 82 reguläre Blobs und keinen eigenständigen Lizenztext. Das unveränderliche
Nuspec verweist auf `xunit/xunit/master/license.txt`; das Assembly-Metadatum nennt
Copyright der .NET Foundation. Das belegt Herkunftsmetadaten, aber keinen
versionsgebundenen vollständigen Lizenztext und keine reproduzierte Binärherkunft.
Der Punkt bleibt offen; kein rechtlicher Schluss aus aktuellen Lizenzdateien.
Quellen: [unveränderlicher Quellstand](https://github.com/xunit/abstractions.xunit/tree/489a2b3949a9ae8587201a22a8ecfc1d791fa1f3),
[Nuspec an diesem Commit](https://github.com/xunit/abstractions.xunit/blob/489a2b3949a9ae8587201a22a8ecfc1d791fa1f3/xunit.abstractions.nuspec).

Aktuelle offizielle React-/Vite-Advisories wurden zusätzlich direkt über deren
öffentliche Hersteller-Repositories abgefragt:33 Einträge gegen48 exakte externe
npm-Lockpakete geprüft, kein betroffener oder nicht auswertbarer Range gefunden.
Die kritischen React-Server-Component-Hinweise vom14.10 betreffen hier nicht
vorhandene `react-server-dom-*`-Pakete. npm-Audit und NuGet-Advisory-Abfrage melden
auf dem geprüften Projektbestand keine bekannten betroffenen Pakete. Das ersetzt
weder semantischen Securityreview noch die dokumentierten Host-/Trustrootgates.

Quellen: [React-Advisories](https://github.com/facebook/react/security/advisories),
[Vite-Advisories](https://github.com/vitejs/vite/security/advisories),
[NuGet-Paketmetadaten](https://www.nuget.org/packages/xunit.abstractions/2.0.3),
[NuGet-Lizenzmetadaten](https://learn.microsoft.com/nuget/reference/nuspec#license).
