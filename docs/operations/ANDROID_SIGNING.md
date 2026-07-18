# Android-Signierung – SchachTurnierManager (STM-MOB-001)

Stand: 2026-07-18

## Grundsatz

Signaturschlüssel gehören **niemals** ins Repository. Sie werden nicht committet, nicht
geloggt, nicht in Reports oder Upload-ZIPs kopiert und nie im Klartext ausgegeben.
Dokumentiert wird ausschließlich der **öffentliche** SHA-256-Zertifikatsfingerabdruck.

## Ablageort des aktuellen Test-/Release-Keys

| | |
|---|---|
| Keystore | `.secrets/local/stm-android-release.jks` (per `.gitignore` ausgeschlossen) |
| Passwort | `.secrets/local/stm-android-release.pw.dpapi` – **DPAPI-geschützt** (nur dieser Windows-Nutzer, dieser Rechner) |
| Alias | `stm-release` |
| Schlüssel | RSA 4096, Gültigkeit 10000 Tage |
| Dname | `CN=SchachTurnierManager, OU=STM, O=<Verein>, L=<Ort>, C=DE` (keine personenbezogenen Daten) |

Das Passwort liegt DPAPI-verschlüsselt vor: Es lässt sich nur vom selben Windows-Benutzerkonto
auf demselben Rechner entschlüsseln. Es steht nirgends im Klartext.

## Öffentlicher Zertifikats-Fingerprint (SHA-256)

```
44:48:80:AE:00:F6:98:68:90:91:EA:A4:BC:43:07:FF:C1:B1:5E:85:F4:57:42:77:37:84:0A:04:54:57:4E:86
```

Dieser Fingerprint identifiziert den Signaturschlüssel. Solange derselbe Keystore verwendet
wird, bleibt er stabil – nur dann sind App-Upgrades ohne Neuinstallation möglich.

## Backup und Wiederherstellung

- **Backup:** Den Keystore `stm-android-release.jks` und die DPAPI-Passwortdatei getrennt
  und offline sichern (z. B. verschlüsselter USB-Stick). **Ohne den Keystore ist kein
  Upgrade einer bereits installierten App mehr möglich** – Android verlangt für ein Update
  denselben Signaturschlüssel.
- **Wichtig zur DPAPI-Grenze:** Die `.pw.dpapi`-Datei ist an Nutzer **und** Rechner gebunden.
  Auf einem anderen Rechner ist sie nicht entschlüsselbar. Für ein Offline-Backup daher das
  Passwort zusätzlich in einem Passwortmanager hinterlegen (nicht im Repo, nicht in diesem
  Dokument).
- **Verlust des Keys:** Geht der Keystore verloren, muss ein neuer erzeugt werden; bestehende
  Installationen müssen dann deinstalliert und neu installiert werden (neuer Fingerprint).

## Signaturprozess (Test-APK)

Der Gradle-Release-Build erzeugt eine unsignierte APK. Signiert wird anschließend mit
`apksigner` aus den Build-Tools:

```
zipalign -v 4 app-release-unsigned.apk app-release-aligned.apk
apksigner sign --ks .secrets/local/stm-android-release.jks --ks-key-alias stm-release \
  --out SchachTurnierManager-<version>-test.apk app-release-aligned.apk
apksigner verify --print-certs SchachTurnierManager-<version>-test.apk
```

Das Keystore-Passwort wird zur Signierzeit aus der DPAPI-Datei entschlüsselt und dem Prozess
nur im Speicher übergeben – nie als Kommandozeilenargument, nie in ein Log.

## Flavor-Trennung

| Flavor | Cleartext-HTTP | Zweck |
|---|---|---|
| **Test** (aktuell) | erlaubt (`network_security_config.xml`, nur privates LAN gedacht) | Companion-Verbindung zum PC ohne HTTPS-Zertifikat, Freitagstest |
| **Release** (offen) | **verboten**, HTTPS erforderlich | Öffentliche Verteilung – siehe Issue #43, noch nicht umgesetzt |

Die Zertifikatsprüfung wird in **keinem** Flavor global abgeschaltet. Der Test-Flavor lässt
lediglich unverschlüsselten Verkehr zu.
