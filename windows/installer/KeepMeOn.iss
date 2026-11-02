; Installer di KeepMeOn per Windows (Inno Setup 6).
; Installa per l'utente corrente in %LOCALAPPDATA%\Programs\KeepMeOn, senza permessi di amministratore.
; Si compila con: ISCC.exe windows\installer\KeepMeOn.iss  (dopo aver compilato l'app in Release)

#define AppName "KeepMeOn"
; Da tenere allineata a <Version> in windows\src\KeepMeOn\KeepMeOn.csproj.
#define AppVersion "1.2.0"
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
; KeepMeOn la chiude [Code] con taskkill: niente gestore riavvio di Windows.
CloseApplications=no
; La lingua si sceglie all'inizio, ogni volta; proposto l'inglese.
ShowLanguageDialog=yes
LanguageDetectionMethod=none
UsePreviousLanguage=no

[Languages]
; Il nome è il codice che legge l'app (Software\KeepMeOn, valore Language) e che l'aggiornamento passa con /LANG.
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"

[CustomMessages]
en.StartupTask=Start KeepMeOn when you sign in to Windows
it.StartupTask=Avvia KeepMeOn all'accesso a Windows
en.Options=Options:
it.Options=Opzioni:

[Tasks]
Name: "startup"; Description: "{cm:StartupTask}"; GroupDescription: "{cm:Options}"

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
; Lingua dell'app: quella scelta nell'installer.
Root: HKCU; Subkey: "Software\KeepMeOn"; ValueType: string; ValueName: "Language"; ValueData: "{language}"; Check: ShouldSaveLanguage

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; Aggiornamento dall'app (installazione silenziosa): riapre KeepMeOn alla fine.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent

[Code]
// L'app resta aperta nell'area di notifica: va chiusa prima di sostituirla o rimuoverla.
procedure StopKeepMeOn();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#AppExe}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

// Un'installazione silenziosa senza /LANG (l'aggiornamento avviato dalla 1.2, o una distribuzione
// aziendale) non ha scelto nessuna lingua: si lascia quella che l'app ha già.
function ShouldSaveLanguage(): Boolean;
var
  I: Integer;
begin
  Result := not WizardSilent;
  for I := 1 to ParamCount do
    if Pos('/LANG=', Uppercase(ParamStr(I))) = 1 then
      Result := True;
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
