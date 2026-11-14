# Shared settings for every tool in this folder.
# PowerShell scripts dot-source this first:   . "<kit folder>\scripts\env.ps1"
# Everything here is relative to this file, so the kit works from any folder.
# (After a move, setup\relocate.ps1 fixes the tools' Python setups; launchers and
# the control panel run it automatically.)
# It keeps model downloads, Python installs and package caches inside this folder
# instead of scattering them across the user profile. Nothing global is changed.

$env:AIA_ROOT = Split-Path -Parent $PSScriptRoot

# Model caches (Hugging Face, torch hub)
$env:HF_HOME    = "$env:AIA_ROOT\models\huggingface"
$env:TORCH_HOME = "$env:AIA_ROOT\models\torch"
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"

# uv: private Python installs and package cache (same drive as the tools, so
# identical packages are hard-linked between environments instead of copied)
$env:UV_PYTHON_INSTALL_DIR = "$env:AIA_ROOT\python"
$env:UV_CACHE_DIR          = "$env:AIA_ROOT\.cache\uv"
$env:UV_PYTHON_PREFERENCE  = "only-managed"
# Don't add python shims to the user's PATH folder or entries to the Windows
# "py" launcher registry when uv installs a Python
$env:UV_PYTHON_INSTALL_BIN      = "0"
$env:UV_PYTHON_INSTALL_REGISTRY = "0"
$env:PIP_CACHE_DIR         = "$env:AIA_ROOT\.cache\pip"
$env:XDG_CACHE_HOME        = "$env:AIA_ROOT\.cache"

# Avoid Windows code-page errors when tools print or read non-ASCII text
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"

# Portable uv / git / ffmpeg that setup\install.ps1 downloads into tools\_bin
# when the PC doesn't have them. Only added when present.
foreach ($aiaBin in @("$env:AIA_ROOT\tools\_bin\ffmpeg\bin", "$env:AIA_ROOT\tools\_bin\git\cmd", "$env:AIA_ROOT\tools\_bin")) {
    if ((Test-Path $aiaBin) -and (($env:PATH -split ';') -notcontains $aiaBin)) { $env:PATH = "$aiaBin;$env:PATH" }
}
# ffmpeg as shared libraries, for tools that load audio through torchcodec (ComfyUI: Fish Audio S2).
# Added at the END of PATH so it never replaces the ffmpeg program in use.
$aiaShared = "$env:AIA_ROOT\tools\_bin\ffmpeg-shared\bin"
if ((Test-Path "$aiaShared\avcodec-62.dll") -and (($env:PATH -split ';') -notcontains $aiaShared)) { $env:PATH = "$env:PATH;$aiaShared" }
Remove-Variable aiaBin -ErrorAction SilentlyContinue
