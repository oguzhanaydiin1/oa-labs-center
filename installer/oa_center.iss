; OA Labs Center — Windows kurulum programı (Inno Setup 6). CI: ISCC /DAppVersion=0.1.0 installer\oa_center.iss
; Yönetici izni istemez: kullanıcının kendi klasörüne kurulur.
; AppId sabit kalmalı: güncellemeler aynı kurulumun üzerine yazılır ve uygulama kendini bu kayıttan bulur.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppExe "oa_center.exe"

[Setup]
; Windows dili Türkçe değilse kurulum İngilizce
ShowLanguageDialog=auto
LanguageDetectionMethod=uilanguage
AppId={{3E7A9C54-1D2B-4F68-A0C3-7B5E9D1F2A46}
AppName=OA Labs Center
AppVersion={#AppVersion}
AppVerName=OA Labs Center {#AppVersion}
AppPublisher=OA Labs
AppPublisherURL=https://oalabs.dev
AppSupportURL=https://oalabs.dev
DefaultDirName={localappdata}\Programs\OA Labs Center
DefaultGroupName=OA Labs Center
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=OA-Labs-Center-Kurulum
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName=OA Labs Center
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\OA Labs Center"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\OA Labs Center"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; Uygulama "Windows açılışında arka planda çalış" için bu değeri kendisi yazar; kaldırınca silinsin
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "OALabsCenter"; Flags: uninsdeletevalue dontcreatekey

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /im oa_center.exe /f"; Flags: runhidden; RunOnceId: "CenterKapat"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,OA Labs Center}"; Flags: nowait postinstall skipifsilent
; Sessiz kurulum (uygulamanın kendini güncellemesi): bitince yeni sürümü aç
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
