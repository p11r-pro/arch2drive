@echo off
REM Scheduler pour arch2drive - execution a 12h00

set RUN_SCRIPT=%~dp0run_arch2drive.bat
set LOG_FILE=%~dp0scheduler.log

echo %date% %time% - Demarrage du scheduler arch2drive >> "%LOG_FILE%"

:WAIT_LOOP
REM Récupérer l'heure actuelle (format 24h)
for /f "tokens=1-2 delims=:" %%a in ("%time%") do (
    set hour=%%a
    set minute=%%b
)

REM Supprimer les espaces de l'heure
set hour=%hour: =%

REM Vérifier si c'est entre 12h00 et 12h59 (pour être sûr de ne pas rater)
if "%hour%"=="12" (
    echo %date% %time% - EXECUTION programmee a 12h00 >> "%LOG_FILE%"
    
    REM Lancer le script d'archivage en mode silencieux
    call "%RUN_SCRIPT%" silent >> "%LOG_FILE%" 2>&1
    
    echo %date% %time% - Execution terminee, attente jusqu'a demain >> "%LOG_FILE%"
    echo ================================================== >> "%LOG_FILE%"
    
    REM Attendre 24 heures (86400 secondes) pour éviter les exécutions multiples
    timeout /t 86400 /nobreak >nul
) else (
    REM Attendre 1 heure avant de re-vérifier
    timeout /t 3600 /nobreak >nul
)

goto WAIT_LOOP
