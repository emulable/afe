@echo off
rem Turn a hum, a sung line or a beatbox take into an instrument track.
rem Drag one or more recordings onto this file. For each one it asks what it
rem is, for example:
rem     this is the melody, on a trumpet
rem     this is the bass line, slap bass
rem     the beat, 808 kit
rem Results (MIDI + WAV) go to music\out.
call "%~dp0..\scripts\env.bat"
title Hum to track
if "%~1"=="" (
    echo Drag a recording ^(wav, mp3, m4a, phone voice memo, ...^) onto this file.
    echo.
    "%AIA_ROOT%\tools\humtools\.venv\Scripts\python.exe" "%AIA_ROOT%\scripts\hum_to_track.py" --help
    echo.
    pause
    exit /b
)
"%AIA_ROOT%\tools\humtools\.venv\Scripts\python.exe" "%AIA_ROOT%\scripts\hum_to_track.py" %*
echo.
pause
