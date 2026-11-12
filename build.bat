@echo off
rem Compila o Conversor de Arquivos e gera o instalador.
rem Requer: Flutter SDK no PATH, Visual Studio com "Desktop development with C++",
rem o Modo de Desenvolvedor do Windows ativado (plugins usam links simbolicos)
rem e o Inno Setup 6 (winget install JRSoftware.InnoSetup) para o instalador.
setlocal
cd /d "%~dp0"

echo === Dependencias ===
call flutter pub get || goto :erro

echo === Analise ===
call flutter analyze || goto :erro

echo === Testes ===
call flutter test || goto :erro

echo === Build release ===
call flutter build windows --release || goto :erro

echo === Instalador ===
set "ISCC="
for %%P in ("%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe" "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe") do (
  if exist %%P set "ISCC=%%~P"
)
if not defined ISCC (
  echo Inno Setup nao encontrado. Instale com: winget install JRSoftware.InnoSetup
  goto :erro
)
rem Versao do pubspec.yaml, sem o numero de build (1.0.0+1 vira 1.0.0).
for /f "tokens=2 delims=: " %%V in ('findstr /b "version:" pubspec.yaml') do set "FULLVER=%%V"
for /f "tokens=1 delims=+" %%V in ("%FULLVER%") do set "APPVER=%%V"
"%ISCC%" /Q /DAppVersion=%APPVER% installer\conversor.iss || goto :erro

echo.
echo Pronto: %~dp0dist\ConversorArquivos-Setup-%APPVER%.exe
echo Envie so esse arquivo. Ele instala o app para o usuario, sem pedir administrador.
exit /b 0

:erro
echo.
echo Falhou. Veja as mensagens acima.
exit /b 1
