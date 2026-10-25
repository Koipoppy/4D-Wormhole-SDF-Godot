@echo off
rem One-shot build for the Windows executable (CMD).
rem Usage: build.bat [path\to\Godot.exe]   (omit if godot is already in PATH)
setlocal
cd /d "%~dp0"

set "GODOT=%~1"
if "%GODOT%"=="" set "GODOT=%GODOT_EXE%"
if "%GODOT%"=="" where godot >nul 2>nul && set "GODOT=godot"
if "%GODOT%"=="" (
	for %%P in ("%LOCALAPPDATA%\Programs\Godot\Godot.exe" "C:\Program Files\Godot\Godot.exe" "%USERPROFILE%\Downloads\Godot.exe") do (
		if exist "%%~P" set "GODOT=%%~P"
	)
)
if "%GODOT%"=="" (
	echo Godot not found. Usage: build.bat "C:\path\to\Godot.exe"
	exit /b 1
)

echo == Godot: %GODOT% ==
"%GODOT%" --version

echo == Importing resources ==
"%GODOT%" --headless --path . --import || goto :fail

echo == Exporting Windows x86_64 (single-file exe, embedded PCK) ==
if not exist build mkdir build
"%GODOT%" --headless --path . --export-release "Windows Desktop" build\4DWormholeEngine.exe || goto :fail

echo Done: build\4DWormholeEngine.exe
exit /b 0

:fail
echo Build failed. Most common cause: export templates not installed -^> Godot editor: Editor ^> Manage Export Templates ^> Download and Install
exit /b 1
