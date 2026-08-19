@echo off
rem power-cut-menu.cmd
rem Double-click this file to set up, pause, or remove the power-cut reminders
rem without typing anything. Keep it in the same folder as power-reminder.ps1.

setlocal
cd /d "%~dp0"
set "PS1=%~dp0power-reminder.ps1"
set "RUN=powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%""

if not exist "%PS1%" (
    echo Cannot find power-reminder.ps1 next to this file.
    echo Keep both files in the same folder.
    pause
    exit /b 1
)

:menu
cls
echo ================================================
echo   Power Cut Reminders
echo ================================================
echo.
%RUN% -Status
echo.
echo   1)  Set up / update reminders (10:00 and 12:00)
echo   2)  Set up with my own times
echo   3)  Show a test pop-up now
echo   4)  Pause the reminders (keeps the setup)
echo   5)  Resume the reminders
echo   6)  Remove the reminders completely
echo   Q)  Quit
echo.
set "choice="
set /p "choice=Choose: "
echo.

if /i "%choice%"=="1" ( %RUN% -Install & goto done )
if /i "%choice%"=="2" goto custom
if /i "%choice%"=="3" ( %RUN% -Test & goto done )
if /i "%choice%"=="4" ( %RUN% -Disable & goto done )
if /i "%choice%"=="5" ( %RUN% -Enable & goto done )
if /i "%choice%"=="6" goto remove
if /i "%choice%"=="Q" exit /b 0
echo Please choose 1-6 or Q.
goto done

:custom
set "times="
set /p "times=Times, 24-hour, comma separated (e.g. 10:00,12:00): "
set "lead="
set /p "lead=How many minutes of warning [2]: "
if not defined lead set "lead=2"
if not defined times (
    echo No times entered.
) else (
    %RUN% -Install -Times %times% -Lead %lead%
)
goto done

:remove
set "yes="
set /p "yes=Really remove all power-cut reminders? [y/N]: "
if /i "%yes%"=="y" ( %RUN% -Uninstall ) else ( echo Cancelled - nothing was changed. )
goto done

:done
echo.
pause
goto menu
