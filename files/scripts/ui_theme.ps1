# AI Audio window look, shared by the control panel (scripts\control_panel.ps1) and the
# installer window (setup\install.ps1): dark / light / match-Windows themes and text size.
# Dot-source it after loading System.Windows.Forms and System.Drawing.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads scripts without a BOM as ANSI.
#
#   $AIATextScale         Windows' "Text size" setting (Settings > Accessibility > Text size),
#                         1.0 to 2.25. Display scaling (e.g. 150%) needs nothing extra: both
#                         windows are DPI-aware, so fonts in points already follow it.
#   New-AIAFont           a font in points, times $AIATextScale
#   Get-AIAThemeSetting   'dark' (the default), 'light' or 'system', read from the panel's
#                         settings file (scripts\control_panel.settings.json, key "Theme")
#   Test-AIADark          turns a setting into dark (true) or light (false)
#   Set-AIARole           marks a control: dim, gray, status, danger, line
#   Set-AIATheme          colours a whole window (call again to switch); a high-contrast
#                         Windows theme always wins
#   Register-AIAToolTip   lets a ToolTip follow the theme
#   New-AIABar/Set-AIABar a flat progress bar (the Windows one can't be made dark)
#   Save-AIAWindowShot    testing aid: picture of a window, title bar included

if (-not ('AIAThemeNative' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AIAThemeNative {
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hwnd, string app, string idList);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
}
'@
}

# ---- text size ---------------------------------------------------------------------------
function Get-AIATextScale {
    # AIA_TEXT_SCALE (e.g. 1.5) overrides Windows' setting, for testing
    if ($env:AIA_TEXT_SCALE) { try { $o = [double]$env:AIA_TEXT_SCALE; if ($o -ge 1 -and $o -le 2.25) { return $o } } catch {} }
    try {
        $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Accessibility' -Name TextScaleFactor -ErrorAction Stop).TextScaleFactor
        if ($v -ge 100 -and $v -le 225) { return [double]$v / 100.0 }
    } catch {}
    return 1.0
}
$AIATextScale = Get-AIATextScale
function New-AIAFont([string]$Family, [double]$Points) {
    New-Object System.Drawing.Font($Family, [single]($Points * $AIATextScale))
}

# ---- which theme ---------------------------------------------------------------------------
function Get-AIAThemeSetting([string]$SettingsPath) {
    try {
        if ($SettingsPath -and (Test-Path $SettingsPath)) {
            $j = Get-Content $SettingsPath -Raw | ConvertFrom-Json
            if (@('dark', 'light', 'system') -contains $j.Theme) { return [string]$j.Theme }
        }
    } catch {}
    return 'dark'
}
function Test-AIASystemDark {
    try { return ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 0) }
    catch { return $false }
}
function Test-AIADark([string]$Setting) {
    if ($Setting -eq 'light') { return $false }
    if ($Setting -eq 'system') { return (Test-AIASystemDark) }
    return $true
}

# ---- colours -------------------------------------------------------------------------------
function New-AIAColor([int]$R, [int]$G, [int]$B) { [System.Drawing.Color]::FromArgb($R, $G, $B) }
$AIAPalettes = @{
    dark = @{
        Back = (New-AIAColor 32 32 32);       Text = (New-AIAColor 236 236 236)
        Dim = (New-AIAColor 172 172 172);     Gray = (New-AIAColor 140 140 140)
        Green = (New-AIAColor 108 203 95);    Amber = (New-AIAColor 240 175 60)
        Red = (New-AIAColor 196 43 28);       RedHover = (New-AIAColor 218 62 46);   RedDown = (New-AIAColor 168 34 22)
        Button = (New-AIAColor 55 55 55);     ButtonHover = (New-AIAColor 68 68 68)
        ButtonDown = (New-AIAColor 82 82 82); ButtonBorder = (New-AIAColor 90 90 90)
        Input = (New-AIAColor 24 24 24);      Line = (New-AIAColor 70 70 70)
        Link = (New-AIAColor 118 185 255);    LinkActive = (New-AIAColor 160 210 255)
        BarTrack = (New-AIAColor 58 58 58);   BarFill = (New-AIAColor 76 160 255)
        TipBack = (New-AIAColor 43 43 43);    TipBorder = (New-AIAColor 95 95 95)
    }
    light = @{
        Back = [System.Drawing.SystemColors]::Control;  Text = [System.Drawing.SystemColors]::ControlText
        Dim = (New-AIAColor 95 95 95);        Gray = (New-AIAColor 120 120 120)
        Green = (New-AIAColor 16 135 60);     Amber = (New-AIAColor 190 120 0)
        Red = (New-AIAColor 196 43 28);       RedHover = (New-AIAColor 214 58 42);   RedDown = (New-AIAColor 168 34 22)
        Input = [System.Drawing.SystemColors]::Window;  Line = (New-AIAColor 200 200 200)
        Link = (New-AIAColor 0 102 204);      LinkActive = (New-AIAColor 0 70 160)
        BarTrack = (New-AIAColor 218 218 218); BarFill = (New-AIAColor 0 120 212)
    }
}
$AIAPalette = $AIAPalettes.dark
$AIAIsDark = $true
$AIARoles = New-Object 'System.Collections.Generic.Dictionary[object,string]'
$AIAToolTips = New-Object System.Collections.ArrayList
$AIAHooked = New-Object 'System.Collections.Generic.HashSet[object]'

function Set-AIARole($Control, [string]$Role) { $AIARoles[$Control] = $Role }

function Register-AIAToolTip($Tip) {
    [void]$AIAToolTips.Add($Tip)
    $Tip.Add_Draw({
        param($s, $e)
        $p = $AIAPalette
        $brush = New-Object System.Drawing.SolidBrush($p.TipBack)
        $e.Graphics.FillRectangle($brush, $e.Bounds); $brush.Dispose()
        $pen = New-Object System.Drawing.Pen($p.TipBorder)
        $e.Graphics.DrawRectangle($pen, 0, 0, $e.Bounds.Width - 1, $e.Bounds.Height - 1); $pen.Dispose()
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $e.ToolTipText, $e.Font, $e.Bounds, $p.Text,
            [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, NoPrefix')
    })
}

# ---- flat progress bar ---------------------------------------------------------------------
function New-AIABar([int]$Width, [int]$Height) {
    $track = New-Object System.Windows.Forms.Panel
    $track.Size = New-Object System.Drawing.Size($Width, $Height)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.Dock = 'Left'
    $fill.Width = 0
    $track.Controls.Add($fill)
    Set-AIARole $track 'bar-track'
    Set-AIARole $fill 'bar-fill'
    return $track
}
function Set-AIABar($Bar, [double]$Fraction) {
    $f = [math]::Min(1.0, [math]::Max(0.0, $Fraction))
    $w = [int][math]::Round($Bar.ClientSize.Width * $f)
    $fill = $Bar.Controls[0]
    if ($fill.Width -ne $w) { $fill.Width = $w }
}

# ---- applying a theme ----------------------------------------------------------------------
function Set-AIAControlColors($C, $P, [bool]$Dark) {
    $role = $null
    [void]$AIARoles.TryGetValue($C, [ref]$role)
    $empty = [System.Drawing.Color]::Empty
    if ($role -eq 'bar-track') { $C.BackColor = $P.BarTrack }
    elseif ($role -eq 'bar-fill') { $C.BackColor = $P.BarFill }
    elseif ($role -eq 'line') { $C.BackColor = $P.Line }
    elseif ($role -eq 'danger') {
        $C.FlatStyle = 'Flat'
        $C.UseVisualStyleBackColor = $false
        $C.BackColor = $P.Red
        $C.ForeColor = [System.Drawing.Color]::White
        $C.FlatAppearance.BorderSize = 0
        $C.FlatAppearance.MouseOverBackColor = $P.RedHover
        $C.FlatAppearance.MouseDownBackColor = $P.RedDown
    }
    elseif ($C -is [System.Windows.Forms.Form]) { $C.BackColor = $P.Back; $C.ForeColor = $P.Text }
    elseif ($C -is [System.Windows.Forms.Button]) {
        if ($Dark) {
            $C.FlatStyle = 'Flat'
            $C.UseVisualStyleBackColor = $false
            $C.BackColor = $P.Button
            $C.ForeColor = $P.Text
            $C.FlatAppearance.BorderSize = 1
            $C.FlatAppearance.BorderColor = $P.ButtonBorder
            $C.FlatAppearance.MouseOverBackColor = $P.ButtonHover
            $C.FlatAppearance.MouseDownBackColor = $P.ButtonDown
        } else {
            $C.FlatStyle = 'Standard'
            $C.BackColor = $empty
            $C.ForeColor = $empty
            $C.UseVisualStyleBackColor = $true
        }
    }
    elseif ($C -is [System.Windows.Forms.ComboBox]) {
        if ($Dark) { $C.FlatStyle = 'Flat'; $C.BackColor = $P.Button; $C.ForeColor = $P.Text }
        else { $C.FlatStyle = 'Standard'; $C.BackColor = [System.Drawing.SystemColors]::Window; $C.ForeColor = [System.Drawing.SystemColors]::WindowText }
    }
    elseif ($C -is [System.Windows.Forms.TextBoxBase]) {
        $C.BackColor = $P.Input
        $C.ForeColor = $P.Text
        if ($Dark) { $C.BorderStyle = 'FixedSingle' } else { $C.BorderStyle = 'Fixed3D' }
    }
    elseif ($C -is [System.Windows.Forms.LinkLabel]) {
        $C.BackColor = $empty
        $C.LinkColor = $P.Link
        $C.VisitedLinkColor = $P.Link
        $C.ActiveLinkColor = $P.LinkActive
    }
    elseif ($C -is [System.Windows.Forms.Label]) {
        $C.BackColor = $empty
        if ($role -eq 'dim') { $C.ForeColor = $P.Dim }
        elseif ($role -eq 'gray') { $C.ForeColor = $P.Gray }
        elseif ($role -ne 'status') { $C.ForeColor = $empty }
    }
    else { $C.BackColor = $empty; $C.ForeColor = $empty }   # panels, check boxes: take the window's colours
    foreach ($child in $C.Controls) { Set-AIAControlColors $child $P $Dark }
}

# title bar and scroll bars are drawn by Windows; they need the window handles
function Set-AIAScrollBars([IntPtr]$Handle, [bool]$Dark) {
    # [NullString]::Value passes a real null (PowerShell would turn $null into "")
    if ($Dark) { [void][AIAThemeNative]::SetWindowTheme($Handle, 'DarkMode_Explorer', [NullString]::Value) }
    else { [void][AIAThemeNative]::SetWindowTheme($Handle, [NullString]::Value, [NullString]::Value) }
}
function Update-AIANative($C) {
    if (-not $C.IsHandleCreated) { return }
    $dark = [bool]$script:AIAIsDark
    if ($C -is [System.Windows.Forms.Form]) {
        $v = [int]$dark
        if ([AIAThemeNative]::DwmSetWindowAttribute($C.Handle, 20, [ref]$v, 4) -ne 0) {
            [void][AIAThemeNative]::DwmSetWindowAttribute($C.Handle, 19, [ref]$v, 4)   # older Windows 10
        }
        Set-AIAScrollBars $C.Handle $dark
        # SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED: redraw the title bar
        [void][AIAThemeNative]::SetWindowPos($C.Handle, [IntPtr]::Zero, 0, 0, 0, 0, 0x37)
    } elseif ($C -is [System.Windows.Forms.TextBoxBase]) {
        Set-AIAScrollBars $C.Handle $dark
    }
    foreach ($child in $C.Controls) { Update-AIANative $child }
}

function Set-AIATheme($Form, [bool]$Dark) {
    $p = $AIAPalettes.light
    if ([System.Windows.Forms.SystemInformation]::HighContrast) {
        # a high-contrast Windows theme wins: use its colours
        $Dark = $false
        $p = $AIAPalettes.light.Clone()
        $p.Dim = [System.Drawing.SystemColors]::ControlText
        $p.Gray = [System.Drawing.SystemColors]::ControlText
        $p.Link = [System.Drawing.SystemColors]::HotTrack
    } elseif ($Dark) { $p = $AIAPalettes.dark }
    $script:AIAPalette = $p
    $script:AIAIsDark = $Dark
    $Form.SuspendLayout()
    Set-AIAControlColors $Form $p $Dark
    $Form.ResumeLayout()
    foreach ($t in $AIAToolTips) { $t.OwnerDraw = $Dark }
    if ($AIAHooked.Add($Form)) {
        # before the window first appears (title bar), and once its controls exist (scroll bars)
        $Form.Add_HandleCreated({ param($s, $e) Update-AIANative $s })
        $Form.Add_Shown({ param($s, $e) Update-AIANative $s })
    }
    Update-AIANative $Form
    $Form.Invalidate($true)
}

# ---- testing aid ---------------------------------------------------------------------------
function Save-AIAWindowShot($Form, [string]$Path) {
    $bmp = New-Object System.Drawing.Bitmap($Form.Width, $Form.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [AIAThemeNative]::PrintWindow($Form.Handle, $hdc, 2)   # PW_RENDERFULLCONTENT: as Windows draws it
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    if (-not $ok) { $Form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $Form.Width, $Form.Height))) }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
