@echo off
rem Narrate documents (.txt .md .docx .pdf .epub .html) with subtitles.
rem   Double-click:            watches narrate\in and narrates anything dropped there.
rem   Drag files onto this:    narrates just those files.
rem Results go to narrate\out (audio + .srt). Voice, speed, format and
rem "make_video" are set in narrate\settings.json (created on first run).
call "%~dp0..\scripts\env.bat"
title Narrate
"%AIA_ROOT%\tools\narrate\.venv\Scripts\python.exe" "%AIA_ROOT%\scripts\narrate.py" %*
echo.
pause
