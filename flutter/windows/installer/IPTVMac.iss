; Inno Setup script for the Windows installer. Built by .github/workflows/windows.yml: iscc /DAppVersion=1.0.0 /DSourceDir=... IPTVMac.iss
; Installs for the current user only (no administrator prompt) under %LocalAppData%\Programs\IPTVMac, with a Start menu entry and an uninstaller.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{6B0F6C6E-4D0D-4D44-9C5C-6F1E5A0A1C01}
AppName=IPTVMac
AppVersion={#AppVersion}
AppPublisher=IPTVMac
AppPublisherURL=https://goelir.github.io/IPTVMac/
AppSupportURL=https://goelir.github.io/IPTVMac/support/
DefaultDirName={localappdata}\Programs\IPTVMac
DefaultGroupName=IPTVMac
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=IPTVMac-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\IPTVMac.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\IPTVMac"; Filename: "{app}\IPTVMac.exe"
Name: "{autodesktop}\IPTVMac"; Filename: "{app}\IPTVMac.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\IPTVMac.exe"; Description: "{cm:LaunchProgram,IPTVMac}"; Flags: nowait postinstall skipifsilent
