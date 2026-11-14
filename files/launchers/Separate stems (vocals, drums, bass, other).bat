@echo off
rem Split songs into four parts (vocals, drums, bass, other) with Demucs.
rem Drag one or more songs onto this file. Results go to music\stems.
rem Uses the GPU; the model (about 300 MB) downloads on first use.
call "%~dp0..\scripts\env.bat"
title Separate stems
if "%~1"=="" (
    echo Drag one or more songs onto this file. The parts are saved in music\stems.
    echo.
    pause
    exit /b
)
"%AIA_ROOT%\tools\separator\.venv\Scripts\audio-separator.exe" %* -m htdemucs_ft.yaml --model_file_dir "%AIA_ROOT%\models\separator" --output_dir "%AIA_ROOT%\music\stems" --output_format WAV
echo.
echo Done. The parts are in "%AIA_ROOT%\music\stems".
pause
