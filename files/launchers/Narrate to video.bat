@echo off
rem Same as Narrate.bat, but always also makes an MP4 with the subtitles burned
rem in. Put a picture at narrate\background.jpg (or .png) to use it as the
rem backdrop; otherwise the subtitles sit on a plain dark background.
rem   Double-click:            watches narrate\in.
rem   Drag files onto this:    narrates just those files.
call "%~dp0..\scripts\env.bat"
title Narrate to video
"%AIA_ROOT%\tools\narrate\.venv\Scripts\python.exe" "%AIA_ROOT%\scripts\narrate.py" --video %*
echo.
pause
