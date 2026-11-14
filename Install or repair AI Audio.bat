@echo off
rem Opens the AI Audio Components window: tick or untick tools, then Apply changes (add,
rem repair or remove). The control panel's Components link opens the same window.
rem Everything goes into this folder. Details: the comment at the top of setup\install.ps1.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0setup\install.ps1"
