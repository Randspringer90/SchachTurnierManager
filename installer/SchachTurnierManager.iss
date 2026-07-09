; Inno-Setup-Skript fuer den SchachTurnierManager (Desktop-Variante).
; Voraussetzung: scripts\Publish-DesktopApp.ps1 wurde ausgefuehrt (output\desktop existiert).
; Build: scripts\Build-Installer.ps1 (findet ISCC.exe und setzt die Version aus package.json).
;
; Eigenschaften:
; - Per-User-Installation ohne Adminrechte (PrivilegesRequired=lowest).
; - Standardpfad: %LocalAppData%\Programs\SchachTurnierManager.
; - Desktop-Verknuepfung (optional) und Startmenue-Eintrag auf SchachTurnierManager.bat.
; - Uninstaller inklusive; Turnierdaten unter %LocalAppData%\SchachTurnierManager bleiben
;   bei der Deinstallation bewusst erhalten (keine Datenvernichtung ohne Nutzerentscheidung).

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif
#define MyAppName "SchachTurnierManager"

[Setup]
AppId={{8CE2230B-3B02-45C3-9D25-037E26DDB180}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=SchachTurnierManager-Projekt
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\output\installer
OutputBaseFilename=SchachTurnierManager_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany=SchachTurnierManager-Projekt
VersionInfoDescription=Lokaler Schachturnier-Manager
VersionInfoProductName={#MyAppName}
CloseApplications=yes

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\output\desktop\app\*"; DestDir: "{app}\app"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\output\desktop\SchachTurnierManager.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\output\desktop\README-Desktop.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\SchachTurnierManager.bat"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\SchachTurnierManager.bat"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\SchachTurnierManager.bat"; Description: "{#MyAppName} jetzt starten"; Flags: postinstall nowait skipifsilent shellexec
