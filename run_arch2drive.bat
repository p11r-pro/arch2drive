@echo off
REM Script pour lancer arch2drive manuellement ou via scheduler

cd /d "%~dp0"

echo %date% %time% - Debut execution arch2drive
"C:\Program Files\Git\bin\bash.exe" "%~dp0arch2drive.sh"

if %ERRORLEVEL% equ 0 (
    echo %date% %time% - SUCCESS: Archive creee avec succes
) else (
    echo %date% %time% - ERREUR: Echec de l'archivage (code %ERRORLEVEL%)
)

echo %date% %time% - Fin execution
echo.

REM Pause seulement si exécuté manuellement (pas via call)
if "%1" NEQ "silent" pause
