@echo off
rem ComfyUI (voices): the audio ComfyUI with TTS Audio Suite - voice-cloning
rem text-to-speech, voice conversion, subtitle (SRT) narration.
rem
rem Runs on port 8189 so it can never collide with another ComfyUI on the PC
rem (ComfyUI's usual port is 8188). Double-click to start; the browser opens by
rem itself once the server is ready. Close this window (or press Ctrl+C) to stop.
rem
rem For scripts:  "ComfyUI (voices).bat" nobrowser   starts it without a browser.

setlocal
call "%~dp0..\scripts\env.bat"
title ComfyUI (voices) - http://127.0.0.1:8189

cd /d "%AIA_ROOT%\tools\ComfyUI"
if not exist ".venv\Scripts\python.exe" (
    echo ComfyUI is not installed at "%AIA_ROOT%\tools\ComfyUI" ^(.venv is missing^).
    pause
    exit /b 1
)

rem Some engines ask PyTorch to compile themselves, which needs a compiler Windows lacks
rem (the sound-effects engine stops with "Cannot find a working triton installation"). Run them plain.
set "TORCHDYNAMO_DISABLE=1"

set "AIA_BROWSER=--auto-launch"
if /i "%~1"=="nobrowser" set "AIA_BROWSER=--disable-auto-launch"

echo Starting ComfyUI (voices) on http://127.0.0.1:8189 ...
".venv\Scripts\python.exe" main.py --listen 127.0.0.1 --port 8189 --enable-manager %AIA_BROWSER%

if errorlevel 1 (
    echo.
    echo ComfyUI stopped with an error. The messages above say why.
    pause
)
endlocal
