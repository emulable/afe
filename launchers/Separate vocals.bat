@echo off
rem Split songs into vocals and instrumental with a BS-RoFormer model (the
rem cleanest vocal split). Handy for: clean reference clips to clone a voice,
rem karaoke backing tracks, or feeding a vocal into ACE-Step / Applio.
rem Drag one or more songs onto this file. Results go to music\stems.
rem Uses the GPU; the model (about 600 MB) downloads on first use.
call "%~dp0..\scripts\env.bat"
title Separate vocals
if "%~1"=="" (
    echo Drag one or more songs onto this file. The parts are saved in music\stems.
    echo.
    pause
    exit /b
)
"%AIA_ROOT%\tools\separator\.venv\Scripts\audio-separator.exe" %* -m model_bs_roformer_ep_317_sdr_12.9755.ckpt --model_file_dir "%AIA_ROOT%\models\separator" --output_dir "%AIA_ROOT%\music\stems" --output_format WAV
echo.
echo Done. The parts are in "%AIA_ROOT%\music\stems".
pause
