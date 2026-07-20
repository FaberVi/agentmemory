@echo off
setlocal
cd /d "%~dp0"
REM Stop conflicting Docker + clean kit state, then start (no prompt).
start "agentmemory-portable" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1" -AutoCleanDocker %*
exit /b 0
