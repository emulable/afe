# Installs the music helper tools. Safe to re-run.
#   tools\humtools   Basic Pitch (hum -> MIDI) + librosa, Python 3.10 so it uses ONNX instead of TensorFlow
#   tools\separator  audio-separator (stem separation: Demucs / RoFormer), GPU build
#   tools\fluidsynth FluidSynth (plays MIDI through a SoundFont to make audio)
#   models\soundfonts\GeneralUser-GS.sf2   free General MIDI instrument set
. "$PSScriptRoot\env.ps1"
# uv prints progress on stderr, which Windows PowerShell 5.1 turns into error
# records, so failures are detected from exit codes rather than from $ErrorActionPreference.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$root = $env:AIA_ROOT

function Step($name) { Write-Host "`n=== $name ===" }

Step 'Python 3.10'
uv python install 3.10
if ($LASTEXITCODE) { throw "Python 3.10 install failed" }

Step 'humtools'
$hum = "$root\tools\humtools"
if (-not (Test-Path "$hum\.venv\Scripts\python.exe")) { uv venv "$hum\.venv" --python 3.10 }
# setuptools<80 still ships pkg_resources, which pretty_midi/resampy import
uv pip install --python "$hum\.venv\Scripts\python.exe" "basic-pitch[onnx]==0.4.0" soundfile mido "setuptools<80"
if ($LASTEXITCODE) { throw "humtools install failed" }

Step 'separator'
$sep = "$root\tools\separator"
if (-not (Test-Path "$sep\.venv\Scripts\python.exe")) { uv venv "$sep\.venv" --python 3.12 }
# audioread is needed by librosa when audio-separator loads files.
# [cpu] = plain onnxruntime: the launchers' models (Demucs, RoFormer) run on the
# GPU through torch; the [gpu] onnxruntime is built for CUDA 13 and only spams
# "Failed to load cublas64_13.dll" next to this CUDA 12.8 torch.
uv pip install --python "$sep\.venv\Scripts\python.exe" "audio-separator[cpu]" audioread "torch==2.8.0+cu128" "torchaudio==2.8.0+cu128" `
    --extra-index-url https://download.pytorch.org/whl/cu128 --index-strategy unsafe-best-match
if ($LASTEXITCODE) { throw "separator install failed" }

Step 'FluidSynth'
$fsDir = "$root\tools\fluidsynth"
if (-not (Get-ChildItem $fsDir -Recurse -Filter fluidsynth.exe -ErrorAction SilentlyContinue)) {
    New-Item -ItemType Directory -Force -Path $fsDir | Out-Null
    $zip = "$fsDir\fluidsynth.zip"
    Invoke-WebRequest -UseBasicParsing -OutFile $zip `
        -Uri 'https://github.com/FluidSynth/fluidsynth/releases/download/v2.6.2/fluidsynth-v2.6.2-win10-x64-cpp11.zip'
    Expand-Archive -Path $zip -DestinationPath $fsDir -Force
    Remove-Item $zip
}
Get-ChildItem $fsDir -Recurse -Filter fluidsynth.exe | Select-Object -ExpandProperty FullName

Step 'GeneralUser GS SoundFont'
$sfDir = "$root\models\soundfonts"
New-Item -ItemType Directory -Force -Path $sfDir | Out-Null
if (-not (Test-Path "$sfDir\GeneralUser-GS.sf2")) {
    Invoke-WebRequest -UseBasicParsing -OutFile "$sfDir\GeneralUser-GS.sf2" `
        -Uri 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/GeneralUser-GS.sf2'
    Invoke-WebRequest -UseBasicParsing -OutFile "$sfDir\GeneralUser-GS README.md" `
        -Uri 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/README.md'
}
'{0:N1} MB' -f ((Get-Item "$sfDir\GeneralUser-GS.sf2").Length / 1MB)

Write-Host "`nDone."
