@echo off
rem Opens the AI Audio control panel: start any tool, see what's running, and
rem stop one tool or everything. It can also stop everything when it closes.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0scripts\control_panel.ps1"
