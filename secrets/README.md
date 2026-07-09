# secrets/ – lokale Geheimnisse, niemals committen


> Hinweis: Neue lokale Secrets bitte bevorzugt unter `.secrets/local/` ablegen.
> Dieser Ordner bleibt als Legacy-/Kompatibilitaetsablage erhalten. Die Skripte pruefen
> beide Orte, bevorzugen aber `.secrets/local/`.

Dieser Ordner ist für **lokale** Zugangsdaten gedacht. In das (öffentlich vorgesehene)
Repository gehören **keine** echten Secrets, Tokens, Passwörter, Zertifikate oder
privaten Konfigurationen.

## Regeln

- Echte Secrets liegen ausschließlich lokal unter `.secrets/local/` oder legacy `secrets/local/` und sind per
  `.gitignore` ausgeschlossen. Nur diese `README.md` ist getrackt.
- Keine `.npmrc` mit Token, keine `.env`, keine API-Keys, keine privaten Schlüssel
  oder Teilnehmer-/PII-Daten im Repo.
- Wird ein Secret benötigt, gelangt es nur als **Prozess-Umgebungsvariable** in den
  Build/Run, nicht als Datei ins Repo.
- Bereits veröffentlichte Secrets gelten als kompromittiert → **rotieren**.

## Lokales Secret sicher ablegen (Windows, DPAPI)

```powershell
# Verschlüsselt nur für den aktuellen Windows-Benutzer; Datei bleibt unter .secrets/local/ (gitignored).
$secure = Read-Host -AsSecureString 'Wert eingeben'
New-Item -ItemType Directory -Force .secrets/local | Out-Null
$secure | ConvertFrom-SecureString | Set-Content .secrets/local/<name>.dpapi.txt
```

```powershell
# Laden und nur als Prozess-Environment setzen (nicht loggen, nicht ausgeben):
$enc = Get-Content .secrets/local/<name>.dpapi.txt
$sec = $enc | ConvertTo-SecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$env:MY_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
```

## Tests

Tests dürfen nur prüfen, ob ein Secret **gesetzt/nicht gesetzt** ist – niemals den Wert.

## Öffentliche Veröffentlichung

Public Release erfolgt nicht direkt aus diesem Repo, sondern über einen geprüften
Clean Snapshot ohne `.git`-Historie:
`scripts/New-OpenSourceSnapshot.ps1` + `scripts/Test-RepositoryOpenSourceSafety.ps1`.
