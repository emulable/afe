@echo off
rem Shared settings for every tool in this folder. Launchers call this first:
rem     call "%~dp0..\scripts\env.bat"
rem It keeps model downloads, Python installs and package caches inside this
rem folder instead of scattering them across the user profile. Nothing global
rem is changed. Keep in step with env.ps1.

for %%I in ("%~dp0..") do set "AIA_ROOT=%%~fI"

rem Model caches (Hugging Face, torch hub)
set "HF_HOME=%AIA_ROOT%\models\huggingface"
set "TORCH_HOME=%AIA_ROOT%\models\torch"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

rem uv: private Python installs and package cache
set "UV_PYTHON_INSTALL_DIR=%AIA_ROOT%\python"
set "UV_CACHE_DIR=%AIA_ROOT%\.cache\uv"
set "UV_PYTHON_PREFERENCE=only-managed"
rem Don't add python shims to the user's PATH folder or entries to the Windows
rem "py" launcher registry when uv installs a Python
set "UV_PYTHON_INSTALL_BIN=0"
set "UV_PYTHON_INSTALL_REGISTRY=0"
set "PIP_CACHE_DIR=%AIA_ROOT%\.cache\pip"
set "XDG_CACHE_HOME=%AIA_ROOT%\.cache"

rem Avoid Windows code-page errors when tools print or read non-ASCII text
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

rem Portable uv / git / ffmpeg that setup\install.ps1 downloads into tools\_bin
rem when the PC doesn't have them. Only added when present.
if exist "%AIA_ROOT%\tools\_bin\uv.exe" set "PATH=%AIA_ROOT%\tools\_bin;%PATH%"
if exist "%AIA_ROOT%\tools\_bin\git\cmd\git.exe" set "PATH=%AIA_ROOT%\tools\_bin\git\cmd;%PATH%"
if exist "%AIA_ROOT%\tools\_bin\ffmpeg\bin\ffmpeg.exe" set "PATH=%AIA_ROOT%\tools\_bin\ffmpeg\bin;%PATH%"
rem ffmpeg as shared libraries, for tools that load audio through torchcodec (ComfyUI: Fish Audio S2).
rem Added at the END of PATH so it never replaces the ffmpeg program in use.
if exist "%AIA_ROOT%\tools\_bin\ffmpeg-shared\bin\avcodec-62.dll" set "PATH=%PATH%;%AIA_ROOT%\tools\_bin\ffmpeg-shared\bin"

rem Portable: if this folder has been moved or copied since it was set up, fix the
rem tools for the new location first (setup\relocate.ps1; offline, usually seconds).
if defined AIA_RELOCATING goto :aia_env_done
if not exist "%AIA_ROOT%\setup\kit-location.txt" goto :aia_env_done
set "AIA_WAS="
set /p AIA_WAS=<"%AIA_ROOT%\setup\kit-location.txt"
if /i "%AIA_WAS%"=="%AIA_ROOT%" goto :aia_env_done
echo This AI Audio folder has moved since it was set up.
echo   was: %AIA_WAS%
echo   now: %AIA_ROOT%
echo Fixing the tools for the new location before starting (no downloads needed) ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AIA_ROOT%\setup\relocate.ps1"
echo.
:aia_env_done
set "AIA_WAS="
