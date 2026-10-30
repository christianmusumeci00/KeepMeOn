; Installer di KeepMeOn per Windows (Inno Setup 6).
; Installa per l'utente corrente in %LOCALAPPDATA%\Programs\KeepMeOn, senza permessi di amministratore.
; Si compila con: ISCC.exe windows\installer\KeepMeOn.iss  (dopo aver compilato l'app in Release)

#define AppName "KeepMeOn"
; Da tenere allineata a <Version> in windows\src\KeepMeOn\KeepMeOn.csproj.
#define AppVersion "1.1.0"
#define AppExe "KeepMeOn.exe"
#define BuildDir "..\src\KeepMeOn\bin\Release\net48"

[Setup]
AppId={{D762AC4D-15C2-4227-A4BD-6C51674750EA}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Christian Musumeci
AppPublisherURL=https://github.com/christianmusumeci00/KeepMeOn
AppSupportURL=https://github.com/christianmusumeci00/KeepMeOn/issues
DefaultDirName={autopf}\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=KeepMeOn-Setup
SetupIconFile=..\src\KeepMeOn\Resources\AppIcon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "startup"; Description: "Avvia KeepMeOn all'accesso a Windows"; GroupDescription: "Opzioni:"

[Files]
Source: "{#BuildDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\{#AppExe}.config"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"

[Registry]
; Stesso valore che scrive l'app con "Avvia all'accesso a Windows".
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#AppExe}"""; Tasks: startup
; Impostazioni dell'app: cancellate con la disinstallazione.
Root: HKCU; Subkey: "Software\KeepMeOn"; Flags: uninsdeletekey

[Run]
Filename: "{app}\{#AppExe}"; Description: "Avvia KeepMeOn"; Flags: nowait postinstall skipifsilent

[Code]
// L'app resta aperta nell'area di notifica: va chiusa prima di sostituirla o rimuoverla.
procedure StopKeepMeOn();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#AppExe}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopKeepMeOn();
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    StopKeepMeOn();
    // L'avvio all'accesso può essere stato attivato anche dall'app: lo si toglie comunque.
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#AppName}');
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', '{#AppName}');
  end;
end;
