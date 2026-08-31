@echo off
setlocal
set "APP_HOME=%~dp0"
set "GRADLE_VERSION=8.3"

where gradle >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  gradle %*
  exit /b %ERRORLEVEL%
)

echo Gradle is not installed. Install Gradle %GRADLE_VERSION% or run this project through Flutter, which provisions Gradle on supported systems.
exit /b 1
