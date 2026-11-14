@echo off
rem Transcribe audio/video to text, broken down by speaker.
rem   Double-click:            watches transcribe\in and processes anything dropped there.
rem   Drag files onto this:    transcribes just those files.
rem Results go to transcribe\out (.txt, .srt, .json).
call "%~dp0..\scripts\env.bat"
title Transcribe (by speaker)
"%AIA_ROOT%\tools\whisperx\.venv\Scripts\python.exe" "%AIA_ROOT%\scripts\transcribe.py" %*
echo.
pause
