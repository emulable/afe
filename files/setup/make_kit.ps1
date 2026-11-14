<#
 make_kit.ps1 - package this AI Audio kit for someone else (or for a fresh PC).

 Writes two equivalent things into <kit>\dist\ :
   AI Audio Setup.ps1   ONE self-contained, human-readable PowerShell file. Every kit file (scripts,
                        launchers, guides, prompt library, installer, version locks, ComfyUI job
                        files) is stored inside as plain text; the designed narrator voices as
                        base64. Running it unpacks the kit and opens the installer.
   AI Audio kit.zip     the same files as an ordinary zip (some antivirus tools distrust big
                        self-unpacking scripts; a zip never has that problem).
 Neither contains tools, models, Python, caches, logs or anything generated (music, narration...).

 Nothing about this PC travels: "My PC notes.md" (the owner's private notes), setup\kit-location.txt
 and setup\private-words.txt are never packed, and the build REFUSES to run if any kit file
 mentions this PC's user folder or account, the kit's own location, or a word listed in
 setup\private-words.txt (one per line; lines starting with # are ignored).

 Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File setup\make_kit.ps1
 Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
#>
$ErrorActionPreference = 'Stop'
$Root = (Split-Path -Parent $PSScriptRoot).TrimEnd('\')
$Dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

# ---- which files make up the kit ---------------------------------------------------------------
function Rel([string]$Full) { $Full.Substring($Root.Length + 1) }
$files = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $Root -File) {
    if ($f.Extension -in @('.md', '.bat') -or $f.Name -in @('LICENSE', '.gitattributes', '.gitignore')) { $files.Add($f.FullName) }
}
foreach ($f in Get-ChildItem (Join-Path $Root 'launchers') -File -Filter *.bat) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'scripts') -File) {
    if ($f.Name -notin @('control_panel.settings.json')) { $files.Add($f.FullName) }
}
foreach ($f in Get-ChildItem (Join-Path $Root 'scripts\comfy_workflows') -File -ErrorAction SilentlyContinue) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'setup') -File -Recurse -Force) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'samples') -File -Filter *.md -ErrorAction SilentlyContinue) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'other-systems') -File -Recurse -ErrorAction SilentlyContinue) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'docs') -File -Recurse -ErrorAction SilentlyContinue) { $files.Add($f.FullName) }
foreach ($f in Get-ChildItem (Join-Path $Root 'voices\reference') -File -ErrorAction SilentlyContinue) {
    if ($f.Name -match '^wise_old_(narrator|narrator_deeper|scholar)\.(wav|txt)$') { $files.Add($f.FullName) }
}
# never packed: the owner's private notes and this PC's own records
$Private = @('My PC notes.md', 'setup\kit-location.txt', 'setup\private-words.txt', 'setup\gpu-memory.txt')
$files = @($files | Where-Object { (Rel $_) -notin $Private -and $_ -notmatch '\\__pycache__\\|\.pyc$' } | Sort-Object -Unique)

# ---- nothing personal may travel -----------------------------------------------------------------
$checks = New-Object System.Collections.Generic.List[object]
function Add-Check([string]$Label, [string]$Pattern) {
    $checks.Add([pscustomobject]@{ Label = $Label; Rx = New-Object Text.RegularExpressions.Regex($Pattern, 'IgnoreCase') })
}
# a folder path in any spelling: \ or / (or doubled, as in JSON), and a space as " " or %20
function PathPattern([string]$p) { ([regex]::Escape($p.TrimEnd('\')) -replace '\\\\', '[\\/]+') -replace '\\ ', '(?: |%20)' }
Add-Check 'your user folder' (PathPattern $env:USERPROFILE)
Add-Check 'your Windows account name' ('[\\/]Users[\\/]+' + [regex]::Escape($env:USERNAME) + '(?![A-Za-z0-9])')
Add-Check "this kit's own location" (PathPattern $Root)
$wordsFile = Join-Path $PSScriptRoot 'private-words.txt'
if (Test-Path $wordsFile) {
    foreach ($w in [IO.File]::ReadAllLines($wordsFile)) {
        $w = $w.Trim()
        if (-not $w -or $w.StartsWith('#')) { continue }
        Add-Check "'$w' (listed in setup\private-words.txt)" ('(?<![A-Za-z0-9])' + [regex]::Escape($w) + '(?![A-Za-z0-9])')
    }
}
$leaks = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
    if ([IO.Path]::GetExtension($f) -eq '.wav') { continue }
    $n = 0
    foreach ($line in [IO.File]::ReadAllLines($f)) {
        $n++
        foreach ($c in $checks) { if ($c.Rx.IsMatch($line)) { $leaks.Add(('  {0}, line {1}: {2}' -f (Rel $f), $n, $c.Label)) } }
    }
}
if ($leaks.Count) {
    Write-Host 'NOT BUILT: these kit files contain details about this PC:' -ForegroundColor Red
    $leaks | ForEach-Object { Write-Host $_ }
    Write-Host 'Edit them out (personal notes belong in "My PC notes.md", which is never packed), then run this again.'
    exit 1
}

# ---- the single-file setup script ---------------------------------------------------------------
$utf8 = New-Object Text.UTF8Encoding($false)
$sb = New-Object Text.StringBuilder
function W([string]$s) { [void]$sb.Append($s); [void]$sb.Append("`r`n") }
$header = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'make_kit_header.txt'))
W $header.TrimEnd()
W "# Kit built $(Get-Date -Format 'yyyy-MM-dd HH:mm') - $($files.Count) files:"
foreach ($f in $files) { W ("#   " + (Rel $f).Replace('\', '/')) }
W ''
W 'param('
W '    [string]$Target,          # where to put the kit (default: an "AI Audio" folder next to this file)'
W '    [switch]$ExtractOnly,     # unpack only; do not open the installer afterwards'
W '    [switch]$Yes              # no questions (use the default or -Target)'
W ')'
W '$ErrorActionPreference = ''Stop'''
W '$KitFiles = New-Object System.Collections.Generic.List[object]'
W 'function Add-KitText([string]$Path, [string]$Eol, [bool]$FinalNewline, [string]$Text) {'
W '    $KitFiles.Add([pscustomobject]@{ Path = $Path; Kind = ''text''; Eol = $Eol; Final = $FinalNewline; Data = $Text })'
W '}'
W 'function Add-KitBinary([string]$Path, [string]$Base64) {'
W '    $KitFiles.Add([pscustomobject]@{ Path = $Path; Kind = ''binary''; Data = $Base64 })'
W '}'
W ''
W '# ============================================================================================'
W '#  THE KIT FILES. Each one is stored as plain text between @'' and ''@ so you can read it here.'
W '#  (A line that itself starts with the two characters quote-at is stored with <<AIA>> in front.)'
W '# ============================================================================================'
foreach ($f in $files) {
    $rel = (Rel $f).Replace('\', '/')
    $bytes = [IO.File]::ReadAllBytes($f)
    $isText = [IO.Path]::GetExtension($f).ToLower() -ne '.wav'
    W ''
    W "# ----- $rel -----"
    if ($isText) {
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $bytes = $bytes[3..($bytes.Length - 1)] }
        $text = $utf8.GetString($bytes)
        $eol = 'lf'; if ($text.Contains("`r`n")) { $eol = 'crlf' }
        $norm = $text -replace "`r`n", "`n"
        $final = $norm.EndsWith("`n")
        if ($final) { $norm = $norm.Substring(0, $norm.Length - 1) }
        $lines = $norm -split "`n" | ForEach-Object { if ($_.StartsWith("'@")) { '<<AIA>>' + $_ } else { $_ } }
        W ("Add-KitText '" + $rel.Replace("'", "''") + "' '$eol' `$" + $final.ToString().ToLower() + " @'")
        foreach ($l in $lines) { W $l }
        W "'@"
    } else {
        $b64 = [Convert]::ToBase64String($bytes)
        W ("Add-KitBinary '" + $rel.Replace("'", "''") + "' @'")
        for ($i = 0; $i -lt $b64.Length; $i += 120) { W $b64.Substring($i, [Math]::Min(120, $b64.Length - $i)) }
        W "'@"
    }
}
W ''
W ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'make_kit_unpacker.txt')).TrimEnd())
$setupPath = Join-Path $Dist 'AI Audio Setup.ps1'
# UTF-8 WITH a byte-order mark, so Windows PowerShell 5.1 reads the guides' special characters correctly
[IO.File]::WriteAllText($setupPath, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))

# ---- the zip -------------------------------------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path $Dist 'AI Audio kit.zip'
if (Test-Path $zipPath) {
    try { Remove-Item $zipPath -Force -ErrorAction Stop }
    catch {
        Write-Host "$setupPath was written, but the zip is open in another program (7-Zip, Explorer...)." -ForegroundColor Yellow
        Write-Host 'Close it there and run this again to rebuild the zip.'
        exit 1
    }
}
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($f in $files) {
        $entry = 'AI Audio/' + (Rel $f).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f, $entry, 'Optimal')
    }
} finally { $zip.Dispose() }

'{0}  {1:N1} MB  ({2} files)' -f $setupPath, ((Get-Item $setupPath).Length / 1MB), $files.Count
'{0}  {1:N1} MB' -f $zipPath, ((Get-Item $zipPath).Length / 1MB)
