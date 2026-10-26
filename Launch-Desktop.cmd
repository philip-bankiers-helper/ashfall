@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0release-profile\Roaming"
set "LOCALAPPDATA=%~dp0release-profile\Local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%~dp0logs" mkdir "%~dp0logs"
if not exist "%~dp0Ashfall.exe" (
  echo Extract the complete Windows release ZIP first. Ashfall.exe is missing.
  pause
  exit /b 1
)
echo ASHFALL Desktop
"%~dp0Ashfall.exe" --log-file "%~dp0logs\game.log" --xr-mode off -- --desktop --extended --playtest-catalog %*
set "result=%ERRORLEVEL%"
if not "%result%"=="0" (
  echo Game exited with code %result%. See logs. No runtime or driver settings were changed.
  pause
)
exit /b %result%
