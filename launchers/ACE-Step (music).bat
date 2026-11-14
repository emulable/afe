@echo off
rem ACE-Step 1.5: music generation. Text to song, covers / style changes
rem (e.g. a reggae version of a song), repaint a section, add backing music to
rem a vocal. Opens http://127.0.0.1:7860 in the browser once it is ready
rem (the first start takes a minute or two while the models load).
rem Results are saved in tools\ACE-Step-1.5\gradio_outputs.
rem Close this window to stop it and free the GPU.
rem
rem Uses the XL (4B) music model: better sound, somewhat slower. On a 16 GB card
rem it is kept at 8-bit and moved off the GPU while the planner runs, so the two
rem never sit in video memory together. "ACE-Step (music, fast).bat" uses the
rem smaller 2B model instead.

setlocal
call "%~dp0..\scripts\env.bat"
set "ACE=%AIA_ROOT%\tools\ACE-Step-1.5"
title ACE-Step (music) - http://127.0.0.1:7860

if not exist "%ACE%\.venv\Scripts\acestep.exe" (
    echo ACE-Step is not installed at "%ACE%".
    pause
    exit /b 1
)
cd /d "%ACE%"

rem Open the browser as soon as the server answers.
start "" /min powershell -NoProfile -WindowStyle Hidden -Command "for($i=0;$i -lt 300;$i++){try{$null=Invoke-WebRequest 'http://127.0.0.1:7860' -UseBasicParsing -TimeoutSec 2;Start-Process 'http://127.0.0.1:7860';break}catch{Start-Sleep 2}}"

".venv\Scripts\acestep.exe" --port 7860 --server-name 127.0.0.1 --language en --config_path acestep-v15-xl-turbo --lm_model_path acestep-5Hz-lm-1.7B --offload_dit_to_cpu true --init_service true

echo.
echo ACE-Step has stopped.
pause
endlocal
