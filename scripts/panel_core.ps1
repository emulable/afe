# Control panel logic: the tool list, "what is running", and stopping things.
# Dot-sourced by control_panel.ps1 (and its background status thread). No UI here.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads scripts without a BOM as ANSI.

$script:AIARoot      = Split-Path -Parent $PSScriptRoot
$script:AIALaunchers = Join-Path $script:AIARoot 'launchers'

# The little PowerShell helper the ACE-Step launchers start to open the browser.
$script:AIAOpenerPattern = '*for($i=0;$i -lt 300;$i++)*127.0.0.1:7860*'

# Helper programs a tool may start that are safe to stop along with it. Anything
# else a tool starts (above all a web browser it opened) is left alone.
$script:AIAHelperNames = @('ffmpeg.exe', 'ffprobe.exe', 'conhost.exe', 'git.exe', 'git-remote-https.exe',
                           'nvidia-smi.exe', 'fluidsynth.exe', 'subst.exe')

# The tool list comes from setup\components.json, the one list the installer also uses.
# Each tool: Key, Component, Kind, Group, Name, Desc, Bat, Port, Url, Results, InDir, Filter, Needs.
# Kind: web = browser app with a port; app = desktop window; watch = drop-folder tool; files = drop files on it
$script:AIARegistry = Get-Content -LiteralPath (Join-Path $script:AIARoot 'setup\components.json') -Raw | ConvertFrom-Json
$script:AIATools = @($script:AIARegistry.tools)

function Test-AIAToolInstalled($Tool) {
    # A tool is shown in the panel only when the files it needs are there.
    foreach ($p in @($Tool.Needs)) {
        if ($p -and -not (Test-Path -LiteralPath (Join-Path $script:AIARoot $p))) { return $false }
    }
    return $true
}

function Get-AIATool([string]$Key) { $script:AIATools | Where-Object { $_.Key -eq $Key } | Select-Object -First 1 }

function Get-AIASelfChain {
    # This process and its ancestors, so the panel never stops itself.
    $ids = @($PID)
    $cur = $PID
    for ($i = 0; $i -lt 10; $i++) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
        if (-not $p -or -not $p.ParentProcessId -or $ids -contains [int]$p.ParentProcessId) { break }
        $cur = [int]$p.ParentProcessId
        $ids += $cur
    }
    return $ids
}

function Get-AIASubstDrives {
    # Drive letters mapped into this folder (Applio's launcher makes one while it runs).
    $map = @{}
    foreach ($line in @(& subst.exe 2>$null)) {
        if ($line -match '^([A-Za-z]):\\: => (.+)$') {
            $target = $Matches[2].Trim()
            if ($target.StartsWith($script:AIARoot, [StringComparison]::OrdinalIgnoreCase)) {
                $map[($Matches[1].ToUpper() + ':')] = $target
            }
        }
    }
    return $map
}

function Resolve-AIAToolKey([string]$t, [string[]]$applioDrives) {
    # $t: lower-case executable paths and command lines of a process and its ancestors
    foreach ($d in $applioDrives) { if ($t -like "*$($d.ToLower())\*") { return 'applio' } }
    if ($t -like '*ace-step (music, fast).bat*') { return 'ace_fast' }
    if ($t -like '*ace-step (music).bat*' -or $t -like '*acestep-v15-xl*') { return 'ace_xl' }
    if ($t -like '*\tools\ace-step-1.5\*' -or $t -like $script:AIAOpenerPattern.ToLower()) { return 'ace_fast' }
    # Narrate before ComfyUI: a ComfyUI that Narrate starts for a cloned voice belongs to Narrate.
    if ($t -like '*narrate to video.bat*' -or ($t -like '*\scripts\narrate.py*' -and $t -like '*--video*')) { return 'narrate_video' }
    if ($t -like '*\launchers\narrate.bat*' -or $t -like '*\scripts\narrate.py*') { return 'narrate' }
    if ($t -like '*comfyui (voices).bat*' -or $t -like '*\tools\comfyui\*') { return 'comfy' }
    if ($t -like '*applio (voice changer).bat*' -or $t -like '*\tools\applio\*') { return 'applio' }
    if ($t -like '*abogen (audiobooks).bat*' -or $t -like '*\tools\abogen\*') { return 'abogen' }
    if ($t -like '*\launchers\transcribe.bat*' -or $t -like '*\scripts\transcribe.py*') { return 'transcribe' }
    if ($t -like '*hum to track.bat*' -or $t -like '*\scripts\hum_to_track.py*' -or $t -like '*\tools\fluidsynth\*') { return 'hum' }
    if ($t -like '*separate vocals.bat*' -or ($t -like '*\tools\separator\*' -and $t -like '*roformer*')) { return 'sep_vocals' }
    if ($t -like '*separate stems*' -or $t -like '*\tools\separator\*') { return 'sep_stems' }
    return 'other'
}

function Get-AIAProcesses {
    # Every running program that belongs to this setup, each tagged with its tool.
    param([int[]]$Exclude = @())
    $root = $script:AIARoot
    $drives = Get-AIASubstDrives
    $applioDrives = @($drives.Keys | Where-Object { $drives[$_] -like '*\tools\Applio*' })
    $conds = @("ExecutablePath LIKE '$($root.Replace('\', '\\'))\\%'", "Name='cmd.exe'", "Name='powershell.exe'")
    foreach ($d in $drives.Keys) { $conds += "ExecutablePath LIKE '$d\\%'" }
    $found = @(Get-CimInstance Win32_Process -Filter ($conds -join ' OR ') -ErrorAction SilentlyContinue)

    $cands = @()
    foreach ($p in $found) {
        if ($Exclude -contains [int]$p.ProcessId) { continue }
        $exe = [string]$p.ExecutablePath
        $cl = [string]$p.CommandLine
        $ok = $false
        if ($exe -and $exe.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { $ok = $true }
        elseif ($exe -and @($drives.Keys | Where-Object { $exe.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }).Count) { $ok = $true }
        elseif ($p.Name -eq 'cmd.exe' -and $cl -like "*$($script:AIALaunchers)\*.bat*") { $ok = $true }
        elseif ($p.Name -eq 'powershell.exe' -and $cl -like $script:AIAOpenerPattern) { $ok = $true }
        if ($ok) { $cands += $p }
    }

    $byId = @{}
    foreach ($p in $cands) { $byId[[int]$p.ProcessId] = $p }
    $out = @()
    foreach ($p in $cands) {
        $text = ''
        $cur = $p
        for ($i = 0; $i -lt 8 -and $cur; $i++) {
            $text += ' ' + [string]$cur.ExecutablePath + ' ' + [string]$cur.CommandLine
            $parent = [int]$cur.ParentProcessId
            if ($parent -eq [int]$cur.ProcessId) { break }
            $cur = $byId[$parent]
        }
        $out += [pscustomobject]@{
            Id = [int]$p.ProcessId; Parent = [int]$p.ParentProcessId; Name = $p.Name
            Key = (Resolve-AIAToolKey $text.ToLower() $applioDrives)
            Worker = ([string]$p.CommandLine -like '*--worker*')
        }
    }
    return $out
}

function Get-AIAGpu {
    try {
        $line = @(& nvidia-smi.exe --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>$null)[0]
        $parts = $line -split ',' | ForEach-Object { [double]$_.Trim() }
        return [pscustomobject]@{ UsedGB = $parts[0] / 1024; TotalGB = $parts[1] / 1024; Util = $parts[2] }
    } catch { return $null }
}

function Get-AIASnapshot {
    # What the panel shows: a state per tool, how many unrecognised programs, GPU memory.
    param([int[]]$Exclude = @())
    $procs = @(Get-AIAProcesses -Exclude $Exclude)
    $ports = @{}
    try {
        foreach ($l in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) { $ports[$l.Port] = $true }
    } catch {}
    $states = @{}
    foreach ($t in $script:AIATools) {
        $mine = @($procs | Where-Object { $_.Key -eq $t.Key })
        $state = 'stopped'
        if ($mine.Count) {
            if ($t.Kind -eq 'web') { if ($ports[$t.Port]) { $state = 'running' } else { $state = 'starting' } }
            elseif (@($mine | Where-Object { $_.Worker }).Count) { $state = 'working' }
            else { $state = 'running' }
        }
        $states[$t.Key] = $state
    }
    return [pscustomobject]@{
        Time = Get-Date; States = $states
        Other = @($procs | Where-Object { $_.Key -eq 'other' }).Count
        Total = $procs.Count; Gpu = (Get-AIAGpu)
    }
}

function Stop-AIAProcessSet([object[]]$Procs) {
    # Stop the given programs plus the helpers they started (ffmpeg, console hosts...),
    # parents first so a drop-folder watcher can't restart its worker. Never a browser.
    if (-not $Procs -or $Procs.Count -eq 0) { return 0 }
    $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name -ErrorAction SilentlyContinue)
    $children = @{}
    foreach ($p in $all) {
        $parent = [int]$p.ParentProcessId
        if (-not $children.ContainsKey($parent)) { $children[$parent] = New-Object System.Collections.ArrayList }
        [void]$children[$parent].Add($p)
    }
    $targets = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($p in $Procs) { if (-not $seen[$p.Id]) { $seen[$p.Id] = $true; [void]$targets.Add($p.Id) } }
    $queue = New-Object System.Collections.Queue
    foreach ($id in @($targets)) { $queue.Enqueue($id) }
    while ($queue.Count) {
        $id = $queue.Dequeue()
        if (-not $children.ContainsKey($id)) { continue }
        foreach ($c in $children[$id]) {
            $cid = [int]$c.ProcessId
            if ($seen[$cid] -or $cid -eq $id) { continue }
            if ($script:AIAHelperNames -contains $c.Name.ToLower()) {
                $seen[$cid] = $true; [void]$targets.Add($cid); $queue.Enqueue($cid)
            }
        }
    }
    # Parents before children: the given set is ordered roots-first below.
    $given = @{}
    foreach ($p in $Procs) { $given[$p.Id] = $p }
    $roots = @($Procs | Where-Object { -not $given.ContainsKey($_.Parent) } | ForEach-Object { $_.Id })
    $ordered = @($roots) + @($targets | Where-Object { $roots -notcontains $_ })
    foreach ($id in $ordered) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    # Wait (up to 5 s) until they are really gone, so GPU memory is free when this returns.
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if (-not @($ordered | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count) { break }
        Start-Sleep -Milliseconds 200
    }
    return $ordered.Count
}

function Remove-AIASubstDrives([string]$Under = $null) {
    $drives = Get-AIASubstDrives
    foreach ($d in @($drives.Keys)) {
        if (-not $Under -or $drives[$d] -like "$Under*") { & subst.exe $d /d 2>$null | Out-Null }
    }
}

function Stop-AIATool {
    param([string]$Key, [int[]]$Exclude = @())
    $procs = @(Get-AIAProcesses -Exclude $Exclude | Where-Object { $_.Key -eq $Key })
    $n = Stop-AIAProcessSet $procs
    if ($Key -eq 'applio') { Remove-AIASubstDrives (Join-Path $script:AIARoot 'tools\Applio') }
    return $n
}

function Stop-AIAAll {
    param([int[]]$Exclude = @())
    $n = Stop-AIAProcessSet @(Get-AIAProcesses -Exclude $Exclude)
    # A second pass catches anything that was starting up during the first.
    $n += Stop-AIAProcessSet @(Get-AIAProcesses -Exclude $Exclude)
    Remove-AIASubstDrives
    return $n
}

function Start-AIATool {
    # Starts the tool's launcher in its own window, optionally with files.
    param([string]$Key, [string[]]$Files = @())
    $t = Get-AIATool $Key
    $bat = Join-Path $script:AIALaunchers $t.Bat
    $line = '/c ""' + $bat + '"'
    foreach ($f in $Files) { $line += ' "' + $f + '"' }
    $line += '"'
    $style = 'Normal'
    if ($t.Kind -eq 'web' -or $t.Kind -eq 'app') { $style = 'Minimized' }
    Start-Process -FilePath 'cmd.exe' -ArgumentList $line -WorkingDirectory $script:AIARoot -WindowStyle $style | Out-Null
}
