<#
 relocate.ps1 - make an AI Audio folder work again after it has been moved, renamed or copied.

 The kit is portable: every script and launcher finds things relative to its own folder.
 The only things that remember an absolute location are inside the tools' Python setups:
   1. python\cpython-3.xx-...      version links (junctions) that point at the full Python folders
   2. tools\<tool>\.venv\           each environment's python.exe launcher and pyvenv.cfg
   3. program launchers (*.exe)     in environments created before they were made relocatable
   4. a few small text files        editable-package .pth files, ComfyUI voice-suite caches and
                                    its nested runtime's pyvenv.cfg
 This script repairs all of them, offline (it reuses the package cache in .cache\uv; it only goes
 online if a package is missing from that cache). It also updates the "AI Audio" desktop shortcut
 if there is one, and records the new location in setup\kit-location.txt.

 It runs by itself: any launcher, and the control panel, notice when the folder has moved and run it.
 By hand:   powershell -NoProfile -ExecutionPolicy Bypass -File setup\relocate.ps1
 Options:   -From "D:\old\place"   the previous location (normally read from kit-location.txt)
            -Convert               also convert old-style environments in place (no move needed), so
                                   later moves only take seconds
 Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
#>
param(
    [string]$From,
    [switch]$Convert
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$SetupDir = $PSScriptRoot
$Root = (Split-Path -Parent $SetupDir).TrimEnd('\')
$env:AIA_RELOCATING = '1'                  # tells env.bat not to start another relocation
. (Join-Path $Root 'scripts\env.ps1')
$Stamp = Join-Path $SetupDir 'kit-location.txt'
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'logs') | Out-Null
$LogFile = Join-Path $Root ('logs\relocate-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$Problems = New-Object System.Collections.ArrayList

function Say([string]$Text) { Write-Host $Text; Add-Content -Path $LogFile -Value $Text -Encoding UTF8 }

function Invoke-Uv([string[]]$UvArgs, [string]$WorkDir) {
    if ($WorkDir) { Push-Location $WorkDir }
    try {
        $out = & uv @UvArgs 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally { if ($WorkDir) { Pop-Location } }
    Add-Content -Path $LogFile -Value (("> uv " + ($UvArgs -join ' ')) + "`r`n" + ($out -join "`r`n")) -Encoding UTF8
    return $code
}

# ---- where was it before? -------------------------------------------------------------------
if (-not $From -and (Test-Path $Stamp)) { $From = (Get-Content $Stamp -Raw).Trim() }
if (-not $From) {
    foreach ($tool in Get-ChildItem (Join-Path $Root 'tools') -Directory -ErrorAction SilentlyContinue) {
        $cfg = Join-Path $tool.FullName '.venv\pyvenv.cfg'
        if (-not (Test-Path $cfg)) { continue }
        $m = Select-String -Path $cfg -Pattern '^home\s*=\s*(.+)$' | Select-Object -First 1
        if ($m -and $m.Matches[0].Groups[1].Value.Trim() -match '^(.*)\\python\\cpython-') { $From = $Matches[1]; break }
    }
}
if ($From) { $From = $From.TrimEnd('\') }
$Moved = [bool]($From -and ($From -ine $Root))

if (-not $Moved -and -not $Convert) {
    [IO.File]::WriteAllText($Stamp, $Root)            # no BOM: env.bat reads this file raw
    Say "AI Audio is where it was set up ($Root). Nothing to fix."
    exit 0
}
if ($Moved) { Say "AI Audio has moved:`r`n  from $From`r`n  to   $Root`r`nFixing the tools for the new location (no downloads needed) ..." }
else { Say "Converting the tools in $Root so that future moves only take seconds ..." }
$t0 = Get-Date

# ---- 1. Python version links --------------------------------------------------------------------
$pyDir = Join-Path $Root 'python'
if (Test-Path $pyDir) {
    foreach ($link in Get-ChildItem $pyDir -Force -Directory | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
        $target = [string](@($link.Target)[0])
        $leaf = Split-Path $target -Leaf
        $newTarget = Join-Path $pyDir $leaf
        if ($target -ieq $newTarget) { continue }
        if (-not (Test-Path (Join-Path $newTarget 'python.exe'))) { [void]$Problems.Add("Python folder $leaf is missing"); continue }
        [IO.Directory]::Delete($link.FullName)                 # removes the link only, never its target
        New-Item -ItemType Junction -Path $link.FullName -Target $newTarget | Out-Null
        Say "  re-linked python\$($link.Name)"
    }
}

# ---- 2. each environment's own python.exe and pyvenv.cfg --------------------------------------
$Envs = @(Get-ChildItem (Join-Path $Root 'tools') -Directory -ErrorAction SilentlyContinue |
          ForEach-Object { Join-Path $_.FullName '.venv' } | Where-Object { Test-Path (Join-Path $_ 'pyvenv.cfg') })
foreach ($venv in $Envs) {
    $name = Split-Path (Split-Path $venv -Parent) -Leaf
    $cfg = Get-Content (Join-Path $venv 'pyvenv.cfg')
    $ver = (($cfg | Select-String '^version_info\s*=\s*(\d+\.\d+)') | Select-Object -First 1).Matches[0].Groups[1].Value
    $a = @('venv', '--allow-existing', '--relocatable', $venv, '--python', $ver)
    $prompt = $cfg | Select-String '^prompt\s*=\s*(.+)$' | Select-Object -First 1
    if ($prompt) { $a += @('--prompt', $prompt.Matches[0].Groups[1].Value.Trim()) }
    if ($cfg | Select-String '^seed\s*=\s*true') { $a += '--seed' }
    if ((Invoke-Uv $a) -ne 0) { [void]$Problems.Add("$name environment could not be re-linked (see $LogFile)") }
    else { Say "  $name environment re-linked" }
}

# ---- 3. small text files that mention the old location ----------------------------------------
if ($Moved) {
    $pairs = @(
        @($From, $Root),
        @($From.Replace('\', '\\'), $Root.Replace('\', '\\')),
        @($From.Replace('\', '/'), $Root.Replace('\', '/')),
        @($From.Replace('\', '/').Replace(' ', '%20'), $Root.Replace('\', '/').Replace(' ', '%20'))
    )
    $exts = @('.pth', '.json', '.cfg', '.ini', '.toml', '.txt', '.yaml', '.yml', '.env')
    $files = New-Object System.Collections.ArrayList
    # tool folders, skipping git data, model weights and the inside of environments
    $stack = New-Object System.Collections.Stack
    $stack.Push((Get-Item (Join-Path $Root 'tools')))
    while ($stack.Count) {
        $dir = $stack.Pop()
        foreach ($item in Get-ChildItem $dir.FullName -Force -ErrorAction SilentlyContinue) {
            if ($item.PSIsContainer) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($item.Name -in @('.git', '.venv', 'checkpoints', 'node_modules', '__pycache__', 'models')) { continue }
                $stack.Push($item)
            } elseif ($exts -contains $item.Extension.ToLower() -and $item.Length -lt 5MB) { [void]$files.Add($item.FullName) }
        }
    }
    # inside environments only the import-path files matter
    foreach ($venv in $Envs) {
        $sp = Join-Path $venv 'Lib\site-packages'
        foreach ($f in Get-ChildItem $sp -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.pth' -or $_.Name -like '__editable__*' }) { [void]$files.Add($f.FullName) }
    }
    $changed = 0
    foreach ($f in $files) {
        $bytes = [IO.File]::ReadAllBytes($f)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($bom) { $text = $text.Substring(1) }
        $new = $text
        foreach ($p in $pairs) { $new = [regex]::Replace($new, [regex]::Escape($p[0]), $p[1].Replace('$', '$$'), 'IgnoreCase') }
        if ($new -ne $text) { [IO.File]::WriteAllText($f, $new, (New-Object Text.UTF8Encoding($bom))); $changed++ }
    }
    Say "  updated the location in $changed small text file(s)"
}

# ---- 4. program launchers that still hold an absolute path -------------------------------------
$Manifest = $null
$manifestFile = Join-Path $SetupDir 'locks\manifest.json'
if (Test-Path $manifestFile) { $Manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json }
$needles = @($Root.ToLower()); if ($From) { $needles += $From.ToLower() }
foreach ($venv in $Envs) {
    $toolDir = Split-Path $venv -Parent
    $name = Split-Path $toolDir -Leaf
    $scripts = Join-Path $venv 'Scripts'
    $stale = @()
    foreach ($exe in Get-ChildItem $scripts -Filter *.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('python.exe', 'pythonw.exe') }) {
        $s = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($exe.FullName)).ToLower()
        if (@($needles | Where-Object { $s.Contains($_) }).Count) { $stale += $exe.Name.ToLower() }
    }
    if (-not $stale.Count) { continue }

    if ($name -eq 'ACE-Step-1.5') {
        # ACE-Step installs itself (editable) from its own uv.lock; re-sync it from the cache.
        $code = Invoke-Uv @('sync', '--frozen', '--offline', '--reinstall') $toolDir
        if ($code -ne 0) { $code = Invoke-Uv @('sync', '--frozen', '--reinstall') $toolDir }
        if ($code -ne 0) { [void]$Problems.Add("ACE-Step launchers could not be rebuilt (see $LogFile)") }
        else { Say "  ACE-Step: rebuilt $($stale.Count) launcher(s)" }
        continue
    }

    # which installed packages own the stale launchers (from their RECORD files)
    $owners = @{}
    $sp = Join-Path $venv 'Lib\site-packages'
    foreach ($di in Get-ChildItem $sp -Directory -Filter '*.dist-info' -ErrorAction SilentlyContinue) {
        $record = Join-Path $di.FullName 'RECORD'
        if (-not (Test-Path $record)) { continue }
        $mine = @(Get-Content $record | ForEach-Object { ($_ -split ',')[0] } | Where-Object { $_ -match '[\\/]Scripts[\\/]([^\\/]+\.exe)$' } | ForEach-Object { $Matches[1].ToLower() })
        if (-not @($mine | Where-Object { $stale -contains $_ }).Count) { continue }
        if (Test-Path (Join-Path $di.FullName 'direct_url.json')) {
            $du = Get-Content (Join-Path $di.FullName 'direct_url.json') -Raw
            if ($du -match '"url"\s*:\s*"file:') { [void]$Problems.Add("$($name): launchers of a locally built package ($($di.Name)) were left as they are"); continue }
        }
        $meta = Get-Content (Join-Path $di.FullName 'METADATA') -TotalCount 20
        $pkg = (($meta | Select-String '^Name:\s*(.+)$') | Select-Object -First 1).Matches[0].Groups[1].Value.Trim()
        $ver = (($meta | Select-String '^Version:\s*(.+)$') | Select-Object -First 1).Matches[0].Groups[1].Value.Trim()
        $owners["$pkg==$ver"] = $true
    }
    if (-not $owners.Count) { continue }
    $py = Join-Path $scripts 'python.exe'
    $common = @('--python', $py, '--index-strategy', 'unsafe-best-match')
    if ($Manifest -and $Manifest.envs.$name) { foreach ($ix in @($Manifest.envs.$name.indexes)) { if ($ix) { $common += @('--extra-index-url', $ix) } } }
    $pkgs = @($owners.Keys)
    $code = Invoke-Uv (@('pip', 'install', '--reinstall', '--no-deps', '--offline') + $common + $pkgs)
    if ($code -ne 0) { $code = Invoke-Uv (@('pip', 'install', '--reinstall', '--no-deps') + $common + $pkgs) }
    if ($code -ne 0) { [void]$Problems.Add("$($name): some launchers could not be rebuilt (see $LogFile)") }
    else { Say "  $($name): rebuilt launchers of $($pkgs.Count) package(s)" }
}

# ---- 5. desktop shortcut ----------------------------------------------------------------------
if ($Moved) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AI Audio.lnk'
    if (Test-Path $lnk) {
        $ws = New-Object -ComObject WScript.Shell
        $s = $ws.CreateShortcut($lnk)
        if ($s.Arguments -like "*$From*" -or $s.WorkingDirectory -ieq $From) {
            $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $Root 'scripts\control_panel.ps1') + '"'
            $s.WorkingDirectory = $Root
            $s.Save()
            Say '  updated the AI Audio desktop shortcut'
        }
    }
}

# ---- done -------------------------------------------------------------------------------------
[IO.File]::WriteAllText($Stamp, $Root)
Say ("Finished in {0:N0} s." -f ((Get-Date) - $t0).TotalSeconds)
if ($Problems.Count) {
    Say 'Some things need attention:'
    foreach ($p in $Problems) { Say "  - $p" }
    Say 'Running "Install or repair AI Audio.bat" and choosing Repair for that tool fixes them.'
    exit 1
}
exit 0
