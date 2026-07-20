# Launcher MCP stdio che usa Node portatile + shim del clone (senza npx sul host).
# In Cursor mcp.json punta a questo .cmd con path assoluto aggiornato alla lettera unita.
@echo off
setlocal
cd /d "%~dp0"
set "KIT=%~dp0"
set "KIT=%KIT:~0,-1%"
set "PATH=%KIT%\portable\node;%PATH%"
set "AGENTMEMORY_URL=http://127.0.0.1:3111"
set "USERPROFILE=%KIT%\home"
set "HOME=%KIT%\home"

if exist "%KIT%\repo\dist\standalone.mjs" (
  "%KIT%\portable\node\node.exe" "%KIT%\repo\dist\standalone.mjs"
  exit /b %ERRORLEVEL%
)

if exist "%KIT%\repo\dist\cli.mjs" (
  "%KIT%\portable\node\node.exe" "%KIT%\repo\dist\cli.mjs" mcp
  exit /b %ERRORLEVEL%
)

if exist "%KIT%\repo\packages\mcp\bin.mjs" (
  "%KIT%\portable\node\node.exe" "%KIT%\repo\packages\mcp\bin.mjs"
  exit /b %ERRORLEVEL%
)

echo [agentmemory-portable] MCP entry non trovata. Esegui setup.cmd / update.cmd 1>&2
exit /b 1
