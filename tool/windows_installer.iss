[Setup]
AppName=NoteNest
AppVersion=1.0.0
DefaultDirName={localappdata}\NoteNest
DefaultGroupName=NoteNest
OutputDir=dist
OutputBaseFilename=NoteNest-Setup-1.0.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=assets\icon\app_icon.ico
UninstallDisplayIcon={app}\notenest.exe
PrivilegesRequired=lowest

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\NoteNest"; Filename: "{app}\notenest.exe"
Name: "{userdesktop}\NoteNest"; Filename: "{app}\notenest.exe"

[Run]
Filename: "{app}\notenest.exe"; Description: "Launch NoteNest"; Flags: nowait postinstall skipifsilent