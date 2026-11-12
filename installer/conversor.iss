; Instalador do Conversor de Arquivos (Inno Setup 6).
; Gerado pelo build.bat:  ISCC.exe /DAppVersion=1.0.0 installer\conversor.iss
; Saída: dist\ConversorArquivos-Setup-<versão>.exe

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Conversor de Arquivos"
#define AppExe "conversor_arquivos.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; Identificador fixo: atualizações substituem a instalação anterior.
AppId={{6F1C2B8E-4D7A-4E5B-9C3F-2A8D1E0B7C64}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
; Instala só para o usuário (%LOCALAPPDATA%\Programs): não pede administrador.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
OutputDir=..\dist
OutputBaseFilename=ConversorArquivos-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Fecha o Conversor se estiver aberto durante a instalação/atualização.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Pasta Release inteira: o .exe precisa das DLLs e da pasta data.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Atalho "Enviar para" criado pelo próprio app ao abrir.
Type: files; Name: "{usersendto}\{#AppName}.lnk"
