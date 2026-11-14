@echo off
rem Abogen: desktop app that turns EPUB / PDF / TXT / Markdown into an
rem audiobook (MP3, M4B with chapters, ...) with synced subtitles, using the
rem Kokoro voices. Good for whole books with chapter handling.
rem Close the app window to stop it.

setlocal
call "%~dp0..\scripts\env.bat"
title Abogen (audiobooks)
set "ABOGEN=%AIA_ROOT%\tools\abogen\.venv\Scripts\abogen.exe"
if not exist "%ABOGEN%" (
    echo Abogen is not installed at "%AIA_ROOT%\tools\abogen".
    pause
    exit /b 1
)
"%ABOGEN%"
if errorlevel 1 pause
endlocal
