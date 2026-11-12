@echo off
rem Compila o Conversor de Arquivos (Windows, release).
rem Requer: Flutter SDK no PATH, Visual Studio com "Desktop development with C++"
rem e o Modo de Desenvolvedor do Windows ativado (plugins usam links simbolicos).
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

echo.
echo Pronto: %~dp0build\windows\x64\runner\Release\conversor_arquivos.exe
echo Para distribuir, copie a pasta Release inteira (o .exe depende das DLLs e da pasta data).
exit /b 0

:erro
echo.
echo Falhou. Veja as mensagens acima.
exit /b 1
