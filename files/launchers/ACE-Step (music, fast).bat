@echo off
rem ACE-Step 1.5 with the smaller 2B music model: quicker results, slightly
rem less detailed sound than the XL model in "ACE-Step (music).bat". Good for
rem rapid-fire idea testing. Same UI, same address, so run only one at a time.
rem Results are saved in tools\ACE-Step-1.5\gradio_outputs.

setlocal
call "%~dp0..\scripts\env.bat"
set "ACE=%AIA_ROOT%\tools\ACE-Step-1.5"
title ACE-Step (music, fast) - http://127.0.0.1:7860

if not exist "%ACE%\.venv\Scripts\acestep.exe" (
    echo ACE-Step is not installed at "%ACE%".
    pause
    exit /b 1
)
cd /d "%ACE%"

rem Open the browser as soon as the server answers.
start "" /min powershell -NoProfile -WindowStyle Hidden -Command "for($i=0;$i -lt 300;$i++){try{$null=Invoke-WebRequest 'http://127.0.0.1:7860' -UseBasicParsing -TimeoutSec 2;Start-Process 'http://127.0.0.1:7860';break}catch{Start-Sleep 2}}"

".venv\Scripts\acestep.exe" --port 7860 --server-name 127.0.0.1 --language en --config_path acestep-v15-turbo --lm_model_path acestep-5Hz-lm-1.7B --init_service true

echo.
echo ACE-Step has stopped.
pause
endlocal
