@echo off
rem Applio: RVC voice conversion. Train a voice model from recordings, then
rem convert your own performance (speech or singing) into that voice.
rem The browser opens by itself. Close this window to stop Applio.
rem
rem Applio refuses to start from a folder whose path contains a space
rem ("AI Audio"), so it is started from a temporary drive letter that points
rem at its folder. The letter is removed when Applio exits (or at sign-out).

setlocal
call "%~dp0..\scripts\env.bat"
set "APPLIO=%AIA_ROOT%\tools\Applio"
title Applio (voice changer)

if not exist "%APPLIO%\.venv\Scripts\python.exe" (
    echo Applio is not installed at "%APPLIO%".
    pause
    exit /b 1
)

set "DRV="
rem Reuse a letter left over from an earlier run that points at Applio.
for %%L in (B R S T U V W) do (
    if not defined DRV if exist "%%L:\core.py" if exist "%%L:\assets\installation_checker.py" set "DRV=%%L:"
)
rem Otherwise map the first free letter.
for %%L in (B R S T U V W) do (
    if not defined DRV if not exist "%%L:\" (
        subst %%L: "%APPLIO%" >nul 2>&1
        if exist "%%L:\core.py" set "DRV=%%L:"
    )
)
if not defined DRV (
    echo Could not find a free drive letter ^(tried B R S T U V W^) for Applio.
    pause
    exit /b 1
)

cd /d %DRV%\
echo Starting Applio from %DRV%\ ^(= %APPLIO%^) ...
"%DRV%\.venv\Scripts\python.exe" app.py --open

cd /d "%AIA_ROOT%"
subst %DRV% /d >nul 2>&1
echo.
echo Applio has stopped.
pause
endlocal
