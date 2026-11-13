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
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Imagens geradas por tool\make_icons.ps1 (1x e 2x para telas com zoom).
WizardImageFile=wizard-large.bmp,wizard-large-2x.bmp
WizardSmallImageFile=wizard-small.bmp,wizard-small-2x.bmp
; Mostra a tela de boas-vindas, onde fica o crédito do ícone.
DisableWelcomePage=no
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

[Messages]
; Texto padrão do Inno em português + crédito exigido pela licença gratuita
; do Flaticon para o ícone.
ptbr.WelcomeLabel2=Isto instalará o [name/ver] no seu computador.%n%nÉ recomendado que você feche todos os outros aplicativos antes de continuar.%n%n%nÍcone: "Data processing icons created by SBTS2018 - Flaticon"%nhttps://www.flaticon.com/free-icons/data-processing

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
