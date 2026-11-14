# AI Audio control panel: start any tool, see what is running, stop one or everything.
# Started by "AI Audio control panel.bat" in the main folder.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads scripts without a BOM as ANSI.
param(
    [string]$SnapshotPng,  # testing aid: draw the window to this PNG file and exit
    [ValidateSet('', 'dark', 'light', 'system')]
    [string]$Theme = ''    # testing aid: use this theme without saving it
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

try {
. (Join-Path $PSScriptRoot 'panel_core.ps1')
. (Join-Path $PSScriptRoot 'ui_theme.ps1')

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AIANative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
[void][AIANative]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$PanelTitle = 'AI Audio control panel'

# ---- one panel at a time ---------------------------------------------------------
if (-not $SnapshotPng) {
    $created = $false
    $script:Mutex = New-Object System.Threading.Mutex($true, 'Local\AIAudioControlPanel', [ref]$created)
    if (-not $created) {
        $other = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq $PanelTitle } | Select-Object -First 1
        if ($other) { [void][AIANative]::ShowWindow($other.MainWindowHandle, 9); [void][AIANative]::SetForegroundWindow($other.MainWindowHandle) }
        exit
    }
}

# ---- moved since it was set up? fix the tools first -------------------------------
$StampFile = Join-Path $AIARoot 'setup\kit-location.txt'
$RelocateScript = Join-Path $AIARoot 'setup\relocate.ps1'
if (-not $SnapshotPng -and (Test-Path $StampFile) -and (Test-Path $RelocateScript)) {
    $was = ([IO.File]::ReadAllText($StampFile)).Trim().TrimEnd('\')
    if ($was -and ($was -ine $AIARoot.TrimEnd('\'))) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "This AI Audio folder has moved:`n`n   from  $was`n   to      $AIARoot`n`nThe tools need a quick fix to work in the new place. It's offline and usually takes seconds (a minute or two the first time).`n`nFix it now?",
            'AI Audio', 'YesNo', 'Question')
        if ($answer -eq 'Yes') {
            Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $RelocateScript + '"')) -Wait
        }
    }
}

# ---- settings ------------------------------------------------------------------
$SettingsPath = Join-Path $PSScriptRoot 'control_panel.settings.json'
$script:StopOnClose = $true
$script:PanelTheme = Get-AIAThemeSetting $SettingsPath     # dark unless changed
try {
    if (Test-Path $SettingsPath) {
        $j = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        if ($null -ne $j.StopOnClose) { $script:StopOnClose = [bool]$j.StopOnClose }
    }
} catch {}
if ($Theme) { $script:PanelTheme = $Theme }
function Save-PanelSettings {
    if ($Theme) { return }   # a test run never changes the saved settings
    try { @{ StopOnClose = $script:StopOnClose; Theme = $script:PanelTheme } | ConvertTo-Json | Set-Content -Path $SettingsPath -Encoding UTF8 } catch {}
}

# ---- look ----------------------------------------------------------------------
# Sizes follow the display scaling (DPI) and Windows' Text size setting ($AIATextScale).
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $Scale = $g.DpiX / 96.0 * $AIATextScale; $g.Dispose()
function Px([double]$v) { [int][math]::Round($v * $Scale) }
function New-Pad($l, $t, $r, $b) { New-Object System.Windows.Forms.Padding((Px $l), (Px $t), (Px $r), (Px $b)) }

$FontBase  = New-AIAFont 'Segoe UI' 9.5
$FontName  = New-AIAFont 'Segoe UI Semibold' 10
$FontSmall = New-AIAFont 'Segoe UI' 8.75
$FontTitle = New-AIAFont 'Segoe UI Semibold' 15
$FontGroup = New-AIAFont 'Segoe UI Semibold' 9.5
$FontState = New-AIAFont 'Segoe UI Semibold' 9.5
$FontBig   = New-AIAFont 'Segoe UI Semibold' 10
$Dot = [string][char]0x25CF
$ThemeNames = [ordered]@{ dark = 'Dark'; light = 'Light'; system = 'Match Windows' }

# ---- state shared with the background status thread ----------------------------
$SelfChain = @(Get-AIASelfChain)
$sync = [hashtable]::Synchronized(@{ Snapshot = $null; Kick = $false; Quit = $false; Error = $null; Exclude = $SelfChain })
$script:Rows = @{}
$script:Pending = @{}       # key -> time a start was requested (shows "Starting..." until it appears)

function Get-State([string]$Key) {
    $snap = $sync.Snapshot
    $state = 'stopped'
    if ($snap) { $state = $snap.States[$Key] }
    if ($state -eq 'stopped' -and $script:Pending.ContainsKey($Key)) {
        if (((Get-Date) - $script:Pending[$Key]).TotalSeconds -lt 20) { $state = 'starting' } else { $script:Pending.Remove($Key) }
    }
    if ($state -ne 'stopped' -and $script:Pending.ContainsKey($Key)) { $script:Pending.Remove($Key) }
    return $state
}
function Request-Refresh { $sync.Kick = $true }

function Show-Info([string]$Text) {
    [void][System.Windows.Forms.MessageBox]::Show($script:Form, $Text, 'AI Audio', 'OK', 'Information')
}

function Invoke-Busy([scriptblock]$Action, [string]$Message) {
    $old = $script:Footer.Text
    $script:Form.UseWaitCursor = $true
    $script:Footer.Text = $Message
    $script:Form.Refresh()
    try { & $Action } finally {
        $script:Form.UseWaitCursor = $false
        $script:Footer.Text = $old
        Request-Refresh
    }
}

function Open-Folder([string]$Relative) {
    $path = Join-Path $AIARoot $Relative
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
    Start-Process explorer.exe -ArgumentList ('"' + $path + '"')
}

function Show-AbogenWindow {
    $p = Get-Process pythonw -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like 'abogen*' } | Select-Object -First 1
    if ($p) { [void][AIANative]::ShowWindow($p.MainWindowHandle, 9); [void][AIANative]::SetForegroundWindow($p.MainWindowHandle) }
}

function Resolve-Conflict($Tool) {
    # Two tools that can't run together: the two ACE-Step launchers (same port), or
    # the two Narrate watchers (same in-folder). Returns $false if the user says no.
    $others = @($AIATools | Where-Object {
        $_.Key -ne $Tool.Key -and $_.Kind -eq $Tool.Kind -and (Get-State $_.Key) -ne 'stopped' -and (
            ($Tool.Kind -eq 'web' -and $_.Port -eq $Tool.Port) -or ($Tool.Kind -eq 'watch' -and $_.InDir -eq $Tool.InDir)) })
    foreach ($o in $others) {
        $answer = [System.Windows.Forms.MessageBox]::Show($script:Form,
            "$($o.Name) is running, and it can't run at the same time as $($Tool.Name).`n`nStop $($o.Name) and start $($Tool.Name)?",
            'AI Audio', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return $false }
        Invoke-Busy { [void](Stop-AIATool -Key $o.Key -Exclude $SelfChain) } "Stopping $($o.Name)..."
    }
    return $true
}

function Start-WithFiles([string]$Key, [string[]]$Files) {
    $Files = @($Files | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if (-not $Files.Count) { return }
    Start-AIATool -Key $Key -Files $Files
    $script:Pending[$Key] = Get-Date
    Request-Refresh
}

function Select-Files([string]$Key) {
    $t = Get-AIATool $Key
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Choose files for $($t.Name)"
    $dlg.Multiselect = $true
    if ($t.Filter) { $dlg.Filter = $t.Filter }
    if ($dlg.ShowDialog($script:Form) -eq 'OK') { Start-WithFiles $Key $dlg.FileNames }
}

function Invoke-Primary([string]$Key) {
    $t = Get-AIATool $Key
    $state = Get-State $Key
    switch ($t.Kind) {
        'web' {
            if ($state -eq 'running') { Start-Process $t.Url; return }
            if ($state -eq 'starting') { Show-Info "$($t.Name) is still starting up. Your browser opens by itself when it's ready."; return }
            if (-not (Resolve-Conflict $t)) { return }
            Start-AIATool -Key $Key
        }
        'app' {
            if ($state -ne 'stopped') { Show-AbogenWindow; return }
            Start-AIATool -Key $Key
        }
        'watch' {
            if ($state -eq 'stopped') {
                if (-not (Resolve-Conflict $t)) { return }
                Start-AIATool -Key $Key
            }
            Open-Folder $t.InDir
        }
        'files' { Select-Files $Key; return }
    }
    $script:Pending[$Key] = Get-Date
    Request-Refresh
}

# ---- window --------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$script:Form = $form
$form.Text = $PanelTitle
$form.Font = $FontBase
$form.AutoScaleMode = 'None'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Padding = New-Pad 16 12 16 12
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:WINDIR\System32\SndVol.exe") } catch {}
$tip = New-Object System.Windows.Forms.ToolTip
Register-AIAToolTip $tip

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.AutoSize = $true
$main.AutoSizeMode = 'GrowAndShrink'
$main.ColumnCount = 1
$form.Controls.Add($main)

# header: title, hint, graphics memory
$title = New-Object System.Windows.Forms.Label
$title.Text = 'AI Audio'
$title.Font = $FontTitle
$title.AutoSize = $true
$title.Margin = New-Pad 0 0 0 2
$main.Controls.Add($title)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = "Start a tool, or drop files onto its button. Stop tools when you're done: they share the graphics card with games and other apps."
Set-AIARole $hint 'dim'
$hint.AutoSize = $true
$hint.MaximumSize = New-Object System.Drawing.Size((Px 760), 0)
$hint.Margin = New-Pad 0 0 0 6
$main.Controls.Add($hint)

$gpuRow = New-Object System.Windows.Forms.FlowLayoutPanel
$gpuRow.AutoSize = $true
$gpuRow.WrapContents = $false
$gpuRow.Margin = New-Pad 0 0 0 6
$gpuLabel = New-Object System.Windows.Forms.Label
$gpuLabel.Text = 'Graphics memory'
$gpuLabel.AutoSize = $true
$gpuLabel.Margin = New-Pad 0 3 8 0
$gpuBar = New-AIABar (Px 260) (Px 14)
$gpuBar.Margin = New-Pad 0 6 10 0
$gpuValue = New-Object System.Windows.Forms.Label
$gpuValue.AutoSize = $true
Set-AIARole $gpuValue 'dim'
$gpuValue.Margin = New-Pad 0 3 0 0
$gpuRow.Controls.AddRange(@($gpuLabel, $gpuBar, $gpuValue))
$main.Controls.Add($gpuRow)
foreach ($c in @($gpuBar, $gpuBar.Controls[0])) { $tip.SetToolTip($c, 'Everything on the card, including games, the browser and Windows (usually 4-6 GB).') }

# tool rows
$grid = New-Object System.Windows.Forms.TableLayoutPanel
$grid.AutoSize = $true
$grid.AutoSizeMode = 'GrowAndShrink'
$grid.ColumnCount = 6
for ($c = 0; $c -lt 6; $c++) { [void]$grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) }
$main.Controls.Add($grid)

$onDragEnter = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = 'Copy' }
}
$onDragDrop = {
    param($sender, $e)
    Start-WithFiles ([string]$sender.Tag) @($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
}
$onPrimary = { param($sender, $e) Invoke-Primary ([string]$sender.Tag) }
$onFiles   = { param($sender, $e) Select-Files ([string]$sender.Tag) }
$onResults = { param($sender, $e) $t = Get-AIATool ([string]$sender.Tag); Open-Folder $t.Results }
$onStop    = {
    param($sender, $e)
    $t = Get-AIATool ([string]$sender.Tag)
    $script:Pending.Remove($t.Key)
    Invoke-Busy { [void](Stop-AIATool -Key $t.Key -Exclude $SelfChain) } "Stopping $($t.Name)..."
}

function New-RowButton([string]$Text, [string]$Name, [string]$Key, $OnClick) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Name = $Name
    $b.Tag = $Key
    $b.AutoSize = $true
    $b.MinimumSize = New-Object System.Drawing.Size((Px 86), (Px 28))
    $b.Margin = New-Pad 3 3 3 3
    $b.Anchor = 'Left'
    $b.Add_Click($OnClick)
    return $b
}
function Add-GridRow { $grid.RowCount += 1; [void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); return ($grid.RowCount - 1) }

$script:GroupLabels = @{}
$lastGroup = $null
foreach ($t in $AIATools) {
    if ($t.Group -ne $lastGroup) {
        $lastGroup = $t.Group
        $r = Add-GridRow
        $gl = New-Object System.Windows.Forms.Label
        $gl.Text = $t.Group.ToUpper()
        $gl.Font = $FontGroup
        Set-AIARole $gl 'gray'
        $gl.AutoSize = $true
        $top = 8; if ($r -eq 0) { $top = 0 }
        $gl.Margin = New-Pad 0 $top 0 2
        $grid.Controls.Add($gl, 0, $r)
        $grid.SetColumnSpan($gl, 6)
        $script:GroupLabels[$t.Group] = $gl
    }
    $r = Add-GridRow
    $dropable = ($t.Kind -eq 'watch' -or $t.Kind -eq 'files')
    $rowControls = New-Object System.Collections.ArrayList

    $status = New-Object System.Windows.Forms.Label
    $status.Text = ''          # Update-Panel fills in the text and its colour
    $status.Font = $FontState
    Set-AIARole $status 'status'
    $status.AutoSize = $true
    $status.MinimumSize = New-Object System.Drawing.Size((Px 100), 0)
    $status.Anchor = 'Left'
    $status.Margin = New-Pad 0 3 6 3
    $grid.Controls.Add($status, 0, $r)

    $text = New-Object System.Windows.Forms.FlowLayoutPanel
    $text.FlowDirection = 'TopDown'
    $text.WrapContents = $false
    $text.AutoSize = $true
    $text.Anchor = 'Left'
    $text.Margin = New-Pad 0 2 12 2
    $text.Tag = $t.Key
    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = $t.Name
    $nameLabel.Font = $FontName
    $nameLabel.AutoSize = $true
    $nameLabel.Margin = New-Pad 0 0 0 0
    $nameLabel.Tag = $t.Key
    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = $t.Desc
    $descLabel.Font = $FontSmall
    Set-AIARole $descLabel 'dim'
    $descLabel.AutoSize = $true
    $descLabel.MaximumSize = New-Object System.Drawing.Size((Px 440), 0)
    $descLabel.Margin = New-Pad 0 1 0 0
    $descLabel.Tag = $t.Key
    $text.Controls.AddRange(@($nameLabel, $descLabel))
    $grid.Controls.Add($text, 1, $r)

    $primaryText = 'Start'
    if ($t.Kind -eq 'watch') { $primaryText = 'Watch folder' }
    if ($t.Kind -eq 'files') { $primaryText = 'Choose files...' }
    $primary = New-RowButton $primaryText "primary_$($t.Key)" $t.Key $onPrimary
    $grid.Controls.Add($primary, 2, $r)

    if ($t.Kind -eq 'watch') {
        $files = New-RowButton 'Choose files...' "files_$($t.Key)" $t.Key $onFiles
        $grid.Controls.Add($files, 3, $r)
        [void]$rowControls.Add($files)
        $tip.SetToolTip($files, 'Process these files now (or drop files here).')
        $dropTargets = @($primary, $files, $text, $nameLabel, $descLabel)
    } else {
        $dropTargets = @($primary, $text, $nameLabel, $descLabel)
    }
    if ($t.Results) {
        $res = New-RowButton 'Results' "results_$($t.Key)" $t.Key $onResults
        $grid.Controls.Add($res, 4, $r)
        [void]$rowControls.Add($res)
        $tip.SetToolTip($res, "Open $($t.Results)")
    }
    $stop = New-RowButton 'Stop' "stop_$($t.Key)" $t.Key $onStop
    $stop.Enabled = $false
    $grid.Controls.Add($stop, 5, $r)

    if ($dropable) {
        foreach ($c in $dropTargets) { $c.AllowDrop = $true; $c.Add_DragEnter($onDragEnter); $c.Add_DragDrop($onDragDrop) }
        $tip.SetToolTip($primary, 'Click, or drop files here.')
    }
    switch ($t.Kind) {
        'web'   { $tip.SetToolTip($primary, 'Start it. Once running, this opens it in your browser.') }
        'app'   { $tip.SetToolTip($primary, 'Start it, or bring its window to the front.') }
        'watch' { $tip.SetToolTip($primary, "Keep watching $($t.InDir): drop files there and they're processed. Opens that folder.") }
    }
    foreach ($c in @($status, $text, $primary, $stop)) { [void]$rowControls.Add($c) }
    $script:Rows[$t.Key] = @{ Tool = $t; Status = $status; Primary = $primary; Stop = $stop; Controls = $rowControls; Shown = $true }
}

# shown instead of the rows when no tool is installed
$emptyLabel = New-Object System.Windows.Forms.Label
$emptyLabel.Text = 'No tools are installed yet. Click Components (below) to choose what to add.'
$emptyLabel.Font = $FontName
$emptyLabel.AutoSize = $true
$emptyLabel.Margin = New-Pad 0 14 0 14
$emptyLabel.Visible = $false
$main.Controls.Add($emptyLabel)
$script:EmptyShown = $false
$script:GroupShown = @{}
foreach ($g in @($script:GroupLabels.Keys)) { $script:GroupShown[$g] = $true }

function Update-Installed {
    # Show a row only when its tool is installed (components come and go through the
    # Components window). Returns $true when something changed.
    $changed = $false
    $groups = @{}
    foreach ($row in $script:Rows.Values) {
        $on = Test-AIAToolInstalled $row.Tool
        if ($on) { $groups[$row.Tool.Group] = $true }
        if ($on -ne $row.Shown) {
            $row.Shown = $on
            $changed = $true
            foreach ($c in $row.Controls) { $c.Visible = $on }
        }
    }
    # (a control's own Visible reads as false until the window is shown, so remember what was set)
    foreach ($g in @($script:GroupLabels.Keys)) {
        $want = [bool]$groups[$g]
        if ($script:GroupShown[$g] -ne $want) { $script:GroupShown[$g] = $want; $script:GroupLabels[$g].Visible = $want }
    }
    $none = ($groups.Count -eq 0)
    if ($script:EmptyShown -ne $none) { $script:EmptyShown = $none; $emptyLabel.Visible = $none }
    return $changed
}

# bottom: stop everything, stop-on-close, links
$sep = New-Object System.Windows.Forms.Label
$sep.AutoSize = $false
$sep.Height = [math]::Max(1, (Px 1))
Set-AIARole $sep 'line'
$sep.Dock = 'Fill'
$sep.Margin = New-Pad 0 8 0 8
$main.Controls.Add($sep)

$bottom = New-Object System.Windows.Forms.FlowLayoutPanel
$bottom.AutoSize = $true
$bottom.WrapContents = $false
$bottom.Margin = New-Pad 0 0 0 0
$stopAll = New-Object System.Windows.Forms.Button
$stopAll.Name = 'stopAll'
$stopAll.Text = 'Stop everything'
$stopAll.Font = $FontBig
$stopAll.AutoSize = $true
$stopAll.MinimumSize = New-Object System.Drawing.Size((Px 150), (Px 36))
Set-AIARole $stopAll 'danger'   # red in every theme
$stopAll.Margin = New-Pad 0 0 14 0
$stopAll.Add_Click({
    $script:Pending.Clear()
    Invoke-Busy { [void](Stop-AIAAll -Exclude $SelfChain) } 'Stopping everything...'
})
$tip.SetToolTip($stopAll, 'Stop every AI Audio tool and free the graphics card. Your browser and other programs are not touched.')

$chk = New-Object System.Windows.Forms.CheckBox
$chk.Name = 'stopOnClose'
$chk.Text = 'Stop everything when this panel closes'
$chk.AutoSize = $true
$chk.Checked = $script:StopOnClose
$chk.Margin = New-Pad 0 8 18 0
$chk.Add_CheckedChanged({ $script:StopOnClose = $chk.Checked; Save-PanelSettings })

$links = New-Object System.Windows.Forms.FlowLayoutPanel
$links.AutoSize = $true
$links.WrapContents = $false
$links.Margin = New-Pad 0 8 0 0
# Components: the window for adding, repairing and removing tools
$compLink = New-Object System.Windows.Forms.LinkLabel
$compLink.Name = 'components'
$compLink.Text = 'Components'
$compLink.AutoSize = $true
$compLink.Margin = New-Pad 0 0 12 0
$compLink.Add_LinkClicked({
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden',
        '-File', ('"' + (Join-Path $AIARoot 'setup\install.ps1') + '"'))
})
$tip.SetToolTip($compLink, 'Add, repair or remove tools. This panel shows the tools that are installed.')
$links.Controls.Add($compLink)
foreach ($l in @(@('How-to guide', 'How to use each tool.md'), @('Prompts', 'Tips and prompts.md'), @('README', 'README.md'), @('Open folder', ''))) {
    $ll = New-Object System.Windows.Forms.LinkLabel
    $ll.Text = $l[0]
    $ll.Tag = $l[1]
    $ll.AutoSize = $true
    $ll.Margin = New-Pad 0 0 12 0
    $ll.Add_LinkClicked({
        param($sender, $e)
        if ($sender.Tag) { Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $AIARoot $sender.Tag) + '"') }
        else { Start-Process explorer.exe -ArgumentList ('"' + $AIARoot + '"') }
    })
    $links.Controls.Add($ll)
}
# theme switch: each click moves on to the next (Dark -> Light -> Match Windows)
$themeLink = New-Object System.Windows.Forms.LinkLabel
$themeLink.Name = 'theme'
$themeLink.AutoSize = $true
$themeLink.Margin = New-Pad 6 0 0 0
$themeLink.Add_LinkClicked({
    $keys = @($ThemeNames.Keys)
    $script:PanelTheme = $keys[([array]::IndexOf($keys, $script:PanelTheme) + 1) % $keys.Count]
    Save-PanelSettings
    Set-PanelTheme
})
$tip.SetToolTip($themeLink, 'Click to switch the look: Dark, Light, or Match Windows (follows your Windows colour setting).')
$links.Controls.Add($themeLink)
$bottom.Controls.AddRange(@($stopAll, $chk, $links))
$main.Controls.Add($bottom)

$footer = New-Object System.Windows.Forms.Label
$script:Footer = $footer
$footer.AutoSize = $true
Set-AIARole $footer 'dim'
$footer.Font = $FontSmall
$footer.Margin = New-Pad 0 6 0 0
$footer.Text = ' '
$main.Controls.Add($footer)

# ---- refreshing the window from the latest status ------------------------------
$StateLook = @{      # label and palette colour
    stopped  = @('Stopped', 'Gray')
    starting = @('Starting...', 'Amber')
    running  = @('Running', 'Green')
    working  = @('Working', 'Amber')
}
function Update-Panel {
    $snap = $sync.Snapshot
    foreach ($row in $script:Rows.Values) {
        $t = $row.Tool
        $state = Get-State $t.Key
        $label = $StateLook[$state][0]
        if ($t.Kind -eq 'app' -and $state -eq 'running') { $label = 'Open' }
        if ($t.Kind -eq 'watch' -and $state -eq 'running') { $label = 'Watching' }
        if ($t.Kind -eq 'files' -and $state -eq 'running') { $label = 'Working' }
        $text = "$Dot $label"
        if ($row.Status.Text -ne $text) { $row.Status.Text = $text; $row.Status.ForeColor = $AIAPalette[$StateLook[$state][1]] }
        $pt = $row.Primary.Text
        switch ($t.Kind) {
            'web'   { if ($state -eq 'running') { $pt = 'Open' } elseif ($state -eq 'starting') { $pt = 'Starting...' } else { $pt = 'Start' } }
            'app'   { if ($state -eq 'stopped') { $pt = 'Start' } else { $pt = 'Show' } }
            'watch' { if ($state -eq 'stopped') { $pt = 'Watch folder' } else { $pt = 'Open in-folder' } }
        }
        if ($row.Primary.Text -ne $pt) { $row.Primary.Text = $pt }
        $row.Stop.Enabled = ($state -ne 'stopped')
    }
    if ($snap -and $snap.Gpu) {
        $gpu = $snap.Gpu
        Set-AIABar $gpuBar ($gpu.UsedGB / [math]::Max(0.1, $gpu.TotalGB))
        $gpuValue.Text = ('{0:N1} of {1:N0} GB in use' -f $gpu.UsedGB, $gpu.TotalGB)
    } elseif ($snap) { $gpuValue.Text = 'not available' }
    if (-not $form.UseWaitCursor) {
        $msg = ' '
        if ($sync.Error) { $msg = "Status check problem: $($sync.Error)" }
        elseif ($snap -and $snap.Other -gt 0) { $msg = "Also running from this folder: $($snap.Other) other program(s). Stop everything stops them too." }
        if ($footer.Text -ne $msg) { $footer.Text = $msg }
    }
}

# ---- theme ---------------------------------------------------------------------
function Set-PanelTheme {
    $themeLink.Text = 'Theme: ' + $ThemeNames[$script:PanelTheme]
    Set-AIATheme $form (Test-AIADark $script:PanelTheme)
    foreach ($row in $script:Rows.Values) { $row.Status.Text = '' }   # recolour the status lights
    Update-Panel
}
$script:ThemeTick = 0
function Watch-WindowsTheme {
    # "Match Windows": follow a change of the Windows setting within a couple of seconds
    if ($script:PanelTheme -ne 'system') { return }
    $script:ThemeTick++
    if ($script:ThemeTick % 4) { return }
    if ((Test-AIASystemDark) -ne $AIAIsDark) { Set-PanelTheme }
}

# ---- never bigger than the screen: scroll instead ------------------------------
function Set-FitToScreen {
    $work = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $maxH = $work.Height - (Px 16)
    $maxW = $work.Width - (Px 16)
    if ($form.Height -gt $maxH -or $form.Width -gt $maxW) {
        $w = [math]::Min($form.Width + [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + (Px 6), $maxW)
        $h = [math]::Min($form.Height, $maxH)
        $form.AutoSize = $false
        if ($w -lt $maxW) {
            # it fits sideways: scroll up and down only
            $form.HorizontalScroll.Maximum = 0
            $form.HorizontalScroll.Enabled = $false
            $form.HorizontalScroll.Visible = $false
        }
        $form.AutoScroll = $true
        $form.Size = New-Object System.Drawing.Size($w, $h)
        $form.Location = New-Object System.Drawing.Point(($work.Left + [int](($work.Width - $form.Width) / 2)), ($work.Top + [int](($work.Height - $form.Height) / 2)))
        $form.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)   # start at the top, not at the focused button
    }
}
$form.Add_Shown({ Set-FitToScreen })

# ---- follow what is installed --------------------------------------------------
$script:InstTick = 0
function Watch-Installed {
    # every 3 seconds: did the Components window add or remove something?
    $script:InstTick++
    if ($script:InstTick % 6) { return }
    if (Update-Installed) {
        # the rows changed: let the window size itself again, then re-fit it to the screen
        $form.AutoScroll = $false
        $form.AutoSize = $true
        $form.PerformLayout()
        Set-FitToScreen
    }
}
[void](Update-Installed)
Set-PanelTheme

# ---- test snapshot mode --------------------------------------------------------
if ($SnapshotPng) {
    $sync.Snapshot = Get-AIASnapshot -Exclude $SelfChain
    Update-Panel
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point(-4000, -4000)
    $form.ShowInTaskbar = $false
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    Save-AIAWindowShot $form $SnapshotPng
    "saved $SnapshotPng ($($form.Width)x$($form.Height), scale $Scale, text $AIATextScale, theme $($script:PanelTheme), dark $AIAIsDark)"
    $form.Close()
    return
}

# ---- background status thread --------------------------------------------------
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$rs.SessionStateProxy.SetVariable('sync', $sync)
$rs.SessionStateProxy.SetVariable('corePath', (Join-Path $PSScriptRoot 'panel_core.ps1'))
$poller = [powershell]::Create()
$poller.Runspace = $rs
[void]$poller.AddScript({
    . $corePath
    while (-not $sync.Quit) {
        try { $sync.Snapshot = Get-AIASnapshot -Exclude $sync.Exclude; $sync.Error = $null }
        catch { $sync.Error = $_.Exception.Message }
        for ($i = 0; $i -lt 20 -and -not $sync.Kick -and -not $sync.Quit; $i++) { Start-Sleep -Milliseconds 100 }
        $sync.Kick = $false
    }
})
$pollHandle = $poller.BeginInvoke()

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({ Update-Panel; Watch-WindowsTheme; Watch-Installed })
$timer.Start()

$form.Add_FormClosing({
    param($sender, $e)
    $timer.Stop()
    $sync.Quit = $true
    if ($script:StopOnClose) {
        $form.UseWaitCursor = $true
        $footer.Text = 'Stopping everything...'
        $form.Refresh()
        try { [void](Stop-AIAAll -Exclude $SelfChain) } catch {}
    }
})

[System.Windows.Forms.Application]::Run($form)
[void]$pollHandle.AsyncWaitHandle.WaitOne(3000)
try { $poller.Dispose(); $rs.Dispose() } catch {}

} catch {
    [void][System.Windows.Forms.MessageBox]::Show("The control panel hit a problem:`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'AI Audio', 'OK', 'Error')
}
