@echo off

rem First run the stuff in the parent directory, i.e. the atlas builder.
rem It will make atlas.png and atlas.odin based on the stuff in `textures` and `font.ttf`

rem If the atlas builder succeeds then we run the stuff in the current directory,
rem which is the example that shows how to use atlas and do atlased animations.

odin run atlas_builder

set OUT_DIR=build\debug

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build source -out:%OUT_DIR%\game_debug.exe -vet -debug
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Debug build created in %OUT_DIR%
