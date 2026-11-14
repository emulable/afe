# Regenerates setup\locks\*.txt and setup\locks\manifest.json from the CURRENT working install,
# and copies the small config files the installer puts into cloned tools (setup\overlays).
# Run it after you change any tool environment (new package, update, repair), so a fresh
# install reproduces the setup exactly:
#     powershell -NoProfile -ExecutionPolicy Bypass -File "<kit folder>\setup\freeze_locks.ps1"
# Read-only for the tools: it runs "uv pip freeze", "git rev-parse" and "python --version".
# Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less scripts as ANSI).
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts\env.ps1')
$LockDir = Join-Path $PSScriptRoot 'locks'
$OverlayDir = Join-Path $PSScriptRoot 'overlays'
New-Item -ItemType Directory -Force -Path $LockDir, $OverlayDir | Out-Null

function Invoke-Quiet([string]$Exe, [string[]]$Arguments) {
    # Native tools print progress on stderr; Windows PowerShell 5.1 would turn that into errors.
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = & $Exe @Arguments 2>$null; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
    if ($code -ne 0) { throw "$Exe $($Arguments -join ' ') failed with exit code $code" }
    return $out
}

# environment name -> folder (relative to the root) and how it is rebuilt
$Envs = [ordered]@{
    'whisperx'     = @{ Dir = 'tools\whisperx';     Method = 'lock' }
    'narrate'      = @{ Dir = 'tools\narrate';      Method = 'lock' }
    'abogen'       = @{ Dir = 'tools\abogen';       Method = 'lock' }
    'humtools'     = @{ Dir = 'tools\humtools';     Method = 'lock' }
    'separator'    = @{ Dir = 'tools\separator';    Method = 'lock' }
    'Applio'       = @{ Dir = 'tools\Applio';       Method = 'lock' }
    'ComfyUI'      = @{ Dir = 'tools\ComfyUI';      Method = 'lock'; Seed = $true }
    'ACE-Step-1.5' = @{ Dir = 'tools\ACE-Step-1.5'; Method = 'uv-sync-frozen' }
}
# Lines a lock must not contain because they point at this PC's disk. Each is
# re-created another way by the installer.
$DropReasons = @{
    'fish-speech'  = 'installed by TTS-Audio-Suite install.py (it patches the upstream wheel)'
    'acestep'      = 'the ACE-Step project itself, installed by uv sync --frozen'
    'nano-vllm'    = 'bundled in the ACE-Step repo, installed by uv sync --frozen'
}

$manifest = [ordered]@{
    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    note      = 'Written by setup\freeze_locks.ps1 from the working install. Read by setup\install.ps1.'
    uv        = ((Invoke-Quiet 'uv' @('--version')) -split ' ')[1]
    pythons   = @()
    envs      = [ordered]@{}
    repos     = [ordered]@{}
    dropped   = @()
}

foreach ($d in Get-ChildItem (Join-Path $Root 'python') -Directory -ErrorAction SilentlyContinue) {
    if ($d.Name -match '^cpython-(\d+\.\d+\.\d+)-windows') { $manifest.pythons += $Matches[1] }
}

foreach ($name in $Envs.Keys) {
    $e = $Envs[$name]
    $py = Join-Path $Root "$($e.Dir)\.venv\Scripts\python.exe"
    if (-not (Test-Path $py)) { Write-Host "skip $name (no environment at $($e.Dir))"; continue }
    $pyver = (Invoke-Quiet $py @('-I', '-c', 'import platform; print(platform.python_version())')).Trim()
    $lines = @(Invoke-Quiet 'uv' @('pip', 'freeze', '--python', $py))
    $kept = New-Object System.Collections.ArrayList
    $tags = @{}
    foreach ($l in $lines) {
        $l = $l.Trim()
        if (-not $l) { continue }
        if ($l -match '^-e ' -or $l -match '@ file:') {
            $pkg = ($l -replace '^-e\s+', '') -replace '\s*@.*$', ''
            if ($l -match '^-e ') { $pkg = 'acestep' }
            $reason = $DropReasons[$pkg]
            if (-not $reason) { $reason = 'local path; not reproducible from a public source' }
            # record it without the local path (it names this PC's folders and user account)
            $shown = $l -replace 'file:/*\S+', 'file:<local path>'
            $manifest.dropped += [ordered]@{ env = $name; line = $shown; reason = $reason }
            continue
        }
        if ($l -match '\+(cu\d{3})\b') { $tags[$Matches[1]] = $true }
        [void]$kept.Add($l)
    }
    $indexes = @($tags.Keys | Sort-Object | ForEach-Object { "https://download.pytorch.org/whl/$_" })
    $file = "$name.txt"
    if ($e.Method -ne 'lock') { $file = "$name.reference.txt" }
    $header = @(
        "# Frozen from $($e.Dir) on $($manifest.generated) by setup\freeze_locks.ps1",
        "# python: $pyver",
        "# extra indexes: $($indexes -join ' ')",
        "# method: $($e.Method)"
    )
    if ($e.Method -ne 'lock') { $header += '# REFERENCE ONLY: this environment is rebuilt from the project''s own uv.lock (uv sync --frozen).' }
    Set-Content -Path (Join-Path $LockDir $file) -Value ($header + $kept) -Encoding ascii
    $manifest.envs[$name] = [ordered]@{
        dir = $e.Dir; python = $pyver; method = $e.Method; lock = $file
        indexes = $indexes; seed = [bool]$e.Seed; packages = $kept.Count
    }
    Write-Host ("{0,-14} python {1,-8} {2,4} packages  {3}" -f $name, $pyver, $kept.Count, ($indexes -join ' '))
}

$Repos = [ordered]@{
    'ACE-Step-1.5'    = 'tools\ACE-Step-1.5'
    'Applio'          = 'tools\Applio'
    'ComfyUI'         = 'tools\ComfyUI'
    'TTS-Audio-Suite' = 'tools\ComfyUI\custom_nodes\TTS-Audio-Suite'
}
foreach ($name in $Repos.Keys) {
    $dir = Join-Path $Root $Repos[$name]
    if (-not (Test-Path (Join-Path $dir '.git'))) { continue }
    $branch = (Invoke-Quiet 'git' @('-C', $dir, 'rev-parse', '--abbrev-ref', 'HEAD')).Trim()
    if ($branch -eq 'HEAD') { $branch = 'main' }   # detached: still give the installer a branch name to create
    $manifest.repos[$name] = [ordered]@{
        dir    = $Repos[$name]
        url    = (Invoke-Quiet 'git' @('-C', $dir, 'remote', 'get-url', 'origin')).Trim()
        commit = (Invoke-Quiet 'git' @('-C', $dir, 'rev-parse', 'HEAD')).Trim()
        branch = $branch
    }
    Write-Host ("{0,-16} {1}" -f $name, $manifest.repos[$name].commit)
}

# Config files that live inside cloned tools (git-ignored there), copied in by the installer
$aceEnv = Join-Path $Root 'tools\ACE-Step-1.5\.env'
if (Test-Path $aceEnv) {
    New-Item -ItemType Directory -Force -Path (Join-Path $OverlayDir 'ACE-Step-1.5') | Out-Null
    Copy-Item $aceEnv (Join-Path $OverlayDir 'ACE-Step-1.5\.env') -Force
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $LockDir 'manifest.json') -Encoding ascii
Write-Host "Wrote $LockDir (dropped $($manifest.dropped.Count) local-path line(s); see manifest.json)"
