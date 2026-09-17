@echo off
title Algebra Book3 Build
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-Book3.ps1" %*
exit /b %ERRORLEVEL%
