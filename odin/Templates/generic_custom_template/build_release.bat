:: This script creates an optimized release build.
@echo off


echo "Building chunk_converter.exe..."
odin build chunk_converter/chunk_converter.odin -file
echo "Converting chunks!..."
chunk_converter.exe convert-all -i data/chunks/ -o data/chunks/ -r

set OUT_DIR=build\release

echo "Building atlas image..."
odin run atlas_builder.odin -file -out:%OUT_DIR%\atlas.png


if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build source\main_release -out:%OUT_DIR%\game_release.exe -strict-style -no-bounds-check -o:speed -subsystem:windows
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i assets %OUT_DIR%\assets > nul

IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Release build created in %OUT_DIR%