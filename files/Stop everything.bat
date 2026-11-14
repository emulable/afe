@echo off
rem Stops every AI Audio tool and frees the graphics card, without opening the
rem control panel. Your browser and other programs are not touched.
title Stop everything (AI Audio)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0scripts\panel_core.ps1'; $n = Stop-AIAAll -Exclude (Get-AIASelfChain); if ($n) { Write-Host \"Stopped $n program(s).\" } else { Write-Host 'Nothing was running.' }"
timeout /t 3 >nul
