# Android Companion: native Source-Adaption von PR55

Diese Quellen erhalten den Companion-Launcher aus PR55/PR49: DE/EN,
zuletzt validierte Serveradresse, App-/Serverversion, Dashboardprüfung und
Test→Connect. Der native GET umgeht die ursprüngliche Browser-CORS-Inkompatibilität,
ohne die CORS-Allowlist des Turnierbackends zu erweitern.

Die Activity lädt die Turnier-WebApp erst nach zwei erfolgreichen Healthprüfungen:
einmal auf „Verbindung testen“ und unmittelbar erneut auf „Verbinden“. Ein
geänderter Eingabewert, Timeout, Lifecyclewechsel oder andere DNS-Zieladresse
invalidiert die Freigabe. Healthantworten sind auf 16 KiB und begrenzte JSON-Tiefe
beschränkt; die absolute Frist einschließlich Body beträgt fünf Sekunden.
Die UI-Frist beendet auch einen blockierten Plattform-DNS-Aufruf. Android kann
dessen internen Resolver nicht immer unterbrechen; ein Worker und eine begrenzte,
bereinigte Queue verhindern deshalb unbeschränkt neue Hintergrundarbeit.

Nur private IPv4-/Loopback-/link-local-Adressen, localhost, IPv6-Loopback und
einlabelige .local-Namen sind Eingabeorigins. Alle DNS-Antworten müssen privat
sein; die Probe und die WebView verwenden anschließend dieselbe literale
private IP. Das verhindert DNS-Rebinding zwischen Probe und Navigation.
IPv6-LAN-Adressen mit Scope-ID sind kein unterstützter Eingang.

HTTPS verwendet die normale Plattform-Zertifikatsprüfung und die ausgewählte IP; bei .local oder
localhost muss das Serverzertifikat daher auch die angezeigte private IP als
SAN enthalten. Es gibt keinen SSL-Bypass und keinen Fall-back auf HTTP.
HTTP ist ausschließlich für den lokalen Source-Candidate vorgesehen. Androids
Netzwerklayer kann dynamische RFC1918-Adressbereiche nicht als Domain-Allowlist
ausdrücken; Origin-/Peerprüfungen erfolgen zusätzlich im nativen Connector.
Ein öffentlich verteilbarer HTTPS-/Flavor-Stand bleibt eine getrennte Aufgabe.

minSdk23 erhält die ursprüngliche Plattformunterstützung. Die Network-Security-
Config mit ausschließlich System-CAs greift ab Android7/API24. API23 verwendet
sein normales Plattformvertrauen, einschließlich dort vom Nutzer installierter
CAs. Das ist kein SSL-Fehler-Bypass. Ausschließlich System-CAs auch auf API23
würden einen gesonderten Trustadapter oder eine ausdrücklich geprüfte Anhebung
von minSdk erfordern; dieser Source-Candidate behauptet diese Zusatzabnahme nicht.

Die WebView darf nur die ausgewählte origin laden. Ein GET-Resourceproxy lehnt
Redirects ab und setzt eine self-only Content-Security-Policy; auch browserseitige
POST-/Fetch-/WebSocket-Aktionen werden dadurch auf diese origin begrenzt.
Worker/ServiceWorker und eingebettete Frames sind über worker-src/child-src im nativen Companion gesperrt;
Offline-PWA-Funktionen bleiben Funktionen der eigenständigen Browser-WebApp.
Resourceantworten sind auf 8 MiB begrenzt. Assets und Health behalten fünf Sekunden; andere API-GETs erhalten 15 Sekunden, die exakt erkannte Paarungsvorschau einschließlich CSV/HTML denselben 130-Sekunden-Vertrag wie die WebApp. Verbindungsaufbau bleibt auf fünf Sekunden begrenzt. Native Bridges, Auth-/Client-
Cert-Dialoge, Dateizugriff, Uploadauswahl, Downloads, Geolocation, Gerätepermissions,
neue Fenster und externe Intents sind gesperrt. Die bestehende WebApp und ihre
normalen same-origin API-Aktionen bleiben Webfunktionalität; die native Probe ist
ausschließlich ein GET ohne Zugangsdaten. Server-/Parserfehler erscheinen als
feste DE/EN-Statusmeldungen, niemals als Rohantworten oder Systemdetails.

## Quellstand und Buildgrenze

Der kleine Gradlequellbaum hat keine Capacitor-/npm-/AndroidX-Dependencies, keinen
Wrapper-JAR und keine PNG/APK/AAB. Icon und Splash sind Android-XML-Quellen.
Appname/-ID folgen dem ursprünglichen Companion. versionName/versionCode werden
aus der kanonischen WebApp-package.json abgeleitet; keine zweite Versionsquelle.

Voraussetzungen für einen später separat erlaubten nativen Build: vorhandenes
Gradle 8.11.1, JDK17 und Android SDK35 samt bereits vorhandenem AGP8.7.2-Cache.
Hier wurde nichts installiert, heruntergeladen, gebaut oder signiert. Fehlen
Voraussetzungen, ist der Build BLOCKED; kein automatischer Wrapperdownload.

Ein möglicher rein lokaler Offline-Build nach gesonderter Freigabe wäre
`gradle --offline --no-daemon :app:assembleDebug` in diesem Quellverzeichnis.
Diese Dokumentation erteilt keine Artifact-/Release-/Deploy-/Kostenfreigabe.

Die Node-Contractsuite kompiliert nur die Android-unabhängige Java-Policy und
Replybegrenzung mit vorhandenem JDK in ein temporäres Verzeichnis. Sie ersetzt
keinen Android-Build und keinen Geräte-/WebView-Smoke. Fehlt das JDK, wird genau
diese Contractsuite mit explizitem Grund übersprungen und muss im Testbericht
als fehlender Nachweis erscheinen.

STM-MOB-001 bleibt bis Build, installiertem Geräteflow und regulärer Signatur-
/Releaseabnahme unvollständig. Eine Sourceintegration behauptet keine APK und
keinen früheren Signatur-/Attestierungsnachweis.

Attribution: adaptierter fachlicher Launcher-/Androidumfang aus PR55,
Quellcommit 2164b99bbb37b9470e4c3eccfb07d6d298d4ee8d, einschließlich PR49.
Generische Templategrafiken und Wrapperbinärdateien werden funktional durch
XML-Source bzw. eine vorhandene lokale Gradleinstallation ersetzt; keine
untrusted Binärattestierung wird als geprüft übernommen.

Offizielle Sicherheitsreferenzen, geprüft am 2026-10-07:
- https://developer.android.com/develop/ui/views/layout/webapps/load-local-content
- https://developer.android.com/privacy-and-security/risks/insecure-webview-native-bridges
- https://developer.android.com/privacy-and-security/security-config

Weitere tatsächlich geprüfte Referenzen:
- https://developer.android.com/reference/android/webkit/WebViewClient
- https://developer.android.com/build/releases/agp-8-7-0-release-notes
- https://www.w3.org/TR/CSP3/
