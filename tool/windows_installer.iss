; NoteNest — Windows installer (Inno Setup 6)
;
; Build the app first:
;     flutter build windows
; Then compile this script (Inno Setup must be on PATH, or use ISCC.exe):
;     iscc tool\windows_installer.iss
; Output: dist\NoteNest-Setup-<version>.exe  (a per-user install, no admin rights)
;
; The version is taken from pubspec.yaml automatically by CI via /DAppVersion=;
; when compiling by hand, the fallback below is used. Keep it in sync with
; `version:` in pubspec.yaml.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "NoteNest"
#define AppPublisher "hamamun"
#define AppURL "https://github.com/hamamun/NoteNest"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases
VersionDisplay={#AppVersion}
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
OutputDir=..\dist
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\assets\icon\app_icon.ico
UninstallDisplayIcon={app}\notenest.exe
UninstallDisplayName={#AppName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallInMode=x64compatible
; Windows 10 and later
MinVersion=10.0
LicenseFile=..\LICENSE
CloseApplications=force
TimeStampsInUTC=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\notenest.exe"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\notenest.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\notenest.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

; NOTE: there is deliberately no [UninstallDelete] section here.
; NoteNest is local-first: for a user who never configured sync, the SQLite
; database in %LOCALAPPDATA%\notenest is the ONLY copy of their notes. An
; uninstall must never quietly destroy it, because the same uninstall is also
; what someone does to "reinstall the app". The leftover is a few megabytes,
; and the dialog below says exactly where it is so it can be removed by hand.

[Code]
// Tell the user what happened to their notes, and how to wipe them for real
// (shared PC, before selling the machine).
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataDir := ExpandConstant('{localappdata}\notenest');
    if DirExists(DataDir) then
      MsgBox(
        'NoteNest has been removed from this PC.' #13#10 #13#10
        'Your notes were NOT deleted. They are still in:' #13#10
        DataDir #13#10 #13#10
        'If you enabled GitHub sync, they are also in your private repository '
        '- reinstall NoteNest and reconnect it to bring everything back.' #13#10 #13#10
        'On a computer you are handing to somebody else, delete the folder above '
        'as well. NoteNest does not do it for you, because it cannot know '
        'whether another copy exists.',
        mbInformation, MB_OK)
    else
      MsgBox(
        'NoteNest has been removed. No note data was found on this computer.',
        mbInformation, MB_OK);
  end;
end;
