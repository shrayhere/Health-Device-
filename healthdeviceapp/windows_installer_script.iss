; Inno Setup Script for Health Device Windows Application
; Pre-configured for HealthDevice release build

#define MyAppName "Health Device"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Health Device Team"
#define MyAppExeName "Health Device.exe"
#define SourceReleaseDir "D:\SG\main files\healthdeviceapp\build\windows\x64\runner\Release"

[Setup]
AppId={{9F82C10D-665C-4BA4-8A87-B27453B04A02}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=D:\SG\MAIN FILES
OutputBaseFilename=HealthDevice_Setup_x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=D:\SG\main files\healthdeviceapp\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "installprereqs"; Description: "Automatically configure and install AI Posture Tracker resources (recommended)"; GroupDescription: "Additional Components:"; Flags: checkedonce

[Files]
; Main Executable
Source: "{#SourceReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; All dependent DLLs, data folder, AI posture tracker, and helper files
Source: "{#SourceReleaseDir}\*"; DestDir: "{app}"; Excludes: "{#MyAppExeName},healthdeviceapp.exe"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\Setup_Prerequisites.bat"; Parameters: "/auto"; Tasks: installprereqs; StatusMsg: "Configuring AI Posture Tracker resources and dependencies..."; Flags: runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
