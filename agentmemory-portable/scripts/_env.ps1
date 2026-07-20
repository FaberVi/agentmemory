# Shared environment for the agentmemory USB portable kit.
# Dot-source from other scripts: . "$PSScriptRoot\_env.ps1"

$ErrorActionPreference = "Stop"

$script:KitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:DataDir = Join-Path $KitRoot "data"
$script:IiiConfigPath = Join-Path $KitRoot "iii-config.yaml"
$script:HomeDir = Join-Path $KitRoot "home"
$script:PortableDir = Join-Path $KitRoot "portable"
$script:NodeDir = Join-Path $PortableDir "node"
$script:NodeExe = Join-Path $NodeDir "node.exe"
$script:AgentmemoryHome = Join-Path $HomeDir ".agentmemory"
$script:IiiBinDir = Join-Path $AgentmemoryHome "bin"
$script:IiiExe = Join-Path $IiiBinDir "iii.exe"
$script:DownloadsDir = Join-Path $KitRoot "downloads"

# Host profile before remapping (needed for git credentials during update)
$script:RealUserProfile = $env:USERPROFILE
$script:RealHome = $env:HOME
$script:RealAppData = $env:APPDATA
$script:RealLocalAppData = $env:LOCALAPPDATA
$script:RealTemp = $env:TEMP
$script:RealTmp = $env:TMP

$script:PinnedIiiVersion = "0.11.2"
$script:PinnedNodeVersion = "22.16.0"
$script:DefaultRepoUrl = "https://github.com/rohitg00/agentmemory.git"

# Layout:
# - in-tree: kit lives at <repo>/agentmemory-portable (pushable with the project)
# - nested:  standalone USB folder with its own repo\ clone
function Test-InTreeLayout {
  $parent = Join-Path $KitRoot ".."
  $pkg = Join-Path $parent "package.json"
  if (-not (Test-Path $pkg)) { return $false }
  try {
    $raw = Get-Content -LiteralPath $pkg -Raw -ErrorAction Stop
    return [bool]($raw -match '"name"\s*:\s*"@agentmemory/agentmemory"')
  } catch {
    return $false
  }
}

$script:InTree = Test-InTreeLayout
if ($InTree) {
  $script:RepoDir = (Resolve-Path (Join-Path $KitRoot "..")).Path
} else {
  $script:RepoDir = Join-Path $KitRoot "repo"
}
$script:CliEntry = Join-Path $RepoDir "dist\cli.mjs"

function Write-KitInfo([string]$Message) {
  Write-Host "[agentmemory-portable] $Message" -ForegroundColor Cyan
}

function Write-KitWarn([string]$Message) {
  Write-Host "[agentmemory-portable] $Message" -ForegroundColor Yellow
}

function Write-KitError([string]$Message) {
  Write-Host "[agentmemory-portable] $Message" -ForegroundColor Red
}

function Get-KitConfig {
  $cfgPath = Join-Path $KitRoot "kit.config.ps1"
  $cfg = [ordered]@{
    RepoUrl     = $DefaultRepoUrl
    IiiVersion  = $PinnedIiiVersion
    NodeVersion = $PinnedNodeVersion
  }
  if (Test-Path $cfgPath) {
    . $cfgPath
    if ($RepoUrl) { $cfg.RepoUrl = $RepoUrl }
    if ($IiiVersion) { $cfg.IiiVersion = $IiiVersion }
    if ($NodeVersion) { $cfg.NodeVersion = $NodeVersion }
  }
  return $cfg
}

function Assert-NodePresent {
  if (-not (Test-Path $NodeExe)) {
    Write-KitError "Node portatile non trovato: $NodeExe"
    Write-KitError "Esegui prima setup.cmd"
    exit 1
  }
}

function Assert-RepoBuilt {
  if (-not (Test-Path $RepoDir)) {
    Write-KitError "Repo assente: $RepoDir"
    Write-KitError "Esegui prima setup.cmd"
    exit 1
  }
  if (-not (Test-Path $CliEntry)) {
    Write-KitError "Build assente: $CliEntry"
    Write-KitError "Esegui setup.cmd oppure update.cmd"
    exit 1
  }
}

function Assert-IiiPresent {
  if (-not (Test-Path $IiiExe)) {
    Write-KitError "iii.exe non trovato: $IiiExe"
    Write-KitError "Esegui prima setup.cmd"
    exit 1
  }
}

function Sync-IiiConfigForLayout {
  if (-not (Test-Path $IiiConfigPath)) { return }
  $raw = Get-Content -LiteralPath $IiiConfigPath -Raw
  if ($InTree) {
    $raw = $raw -replace '(?m)file_path:\s*\.\./data/', 'file_path: ./data/'
    $raw = $raw -replace '(?m)-\s+node repo/dist/index\.mjs', '- node ../dist/index.mjs'
    $raw = $raw -replace '(?m)-\s+src/\*\*/\*\.ts', '- ../src/**/*.ts'
  } else {
    $raw = $raw -replace '(?m)file_path:\s*\./data/', 'file_path: ./data/'
    $raw = $raw -replace '(?m)-\s+node \.\./dist/index\.mjs', '- node repo/dist/index.mjs'
    $raw = $raw -replace '(?m)-\s+\.\./src/\*\*/\*\.ts', '- repo/src/**/*.ts'
  }
  Set-Content -LiteralPath $IiiConfigPath -Value $raw -Encoding UTF8
}

function Assert-UsbDataLayout {
  if (-not (Test-Path $IiiConfigPath)) {
    Write-KitError "Missing kit iii-config.yaml at $IiiConfigPath"
    Write-KitError "Re-copy the kit or re-run setup.cmd"
    exit 1
  }
  if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
  }
  Sync-IiiConfigForLayout
}

function Show-DockerConflictMenu {
  param(
    [string[]]$ContainerNames
  )

  $names = @($ContainerNames | Where-Object { $_ } | Select-Object -Unique)
  $stopCmd = if ($names.Count -gt 0) {
    "docker stop $($names -join ' ')"
  } else {
    "docker stop <nome-container>"
  }

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Yellow
  Write-Host "  ATTENZIONE: Docker locale con agentmemory/iii attivo" -ForegroundColor Yellow
  Write-Host "============================================================" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Il kit USB non puo avviarsi in sicurezza." -ForegroundColor White
  Write-Host "Se proseguisse, agentmemory si aggancierebbe all'engine Docker" -ForegroundColor White
  Write-Host "del PC e i dati finirebbero nel volume Docker, NON sulla pen drive." -ForegroundColor White
  Write-Host ""
  if ($names.Count -gt 0) {
    Write-Host "Container rilevati:" -ForegroundColor Cyan
    foreach ($n in $names) {
      Write-Host "  - $n" -ForegroundColor Cyan
    }
    Write-Host ""
  }
  Write-Host "Scegli un'opzione:" -ForegroundColor Green
  Write-Host ""
  Write-Host "  A) Istruzioni manuali (fermo io Docker, poi rilancio start.cmd)" -ForegroundColor Green
  Write-Host "       Comando tipico: $stopCmd" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "  B) Resta su Docker sul PC (non usare il kit USB adesso)" -ForegroundColor DarkYellow
  Write-Host "       Cursor: http://127.0.0.1:3111" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "  C) Pulisci in automatico e avvia il kit USB" -ForegroundColor Cyan
  Write-Host "       - ferma i container Docker rilevati" -ForegroundColor DarkGray
  Write-Host "       - ripulisce pid/state del kit su questa pen drive" -ForegroundColor DarkGray
  Write-Host "       - NON cancella i volumi Docker (i dati sul PC restano)" -ForegroundColor DarkGray
  Write-Host "       - poi prosegue con start sulla USB (dati in data\)" -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Yellow
}

function Get-AgentmemoryDockerContainers {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) { return @() }

  $names = @()
  $byName = docker ps --format "{{.Names}}" 2>$null | Where-Object { $_ -match "agentmemory|iii-engine|iii" }
  if ($byName) { $names += @($byName) }

  $byPort = docker ps --format "{{.Names}}\t{{.Ports}}" 2>$null | ForEach-Object {
    if ($_ -match "3111|3112|49134") {
      ($_ -split "`t")[0]
    }
  }
  if ($byPort) { $names += @($byPort) }

  return @($names | Where-Object { $_ } | Select-Object -Unique)
}

function Clear-KitRuntimeState {
  Write-KitInfo "Cleaning kit runtime state under home\.agentmemory ..."
  foreach ($name in @("iii.pid", "worker.pid", "engine-state.json")) {
    $p = Join-Path $AgentmemoryHome $name
    if (Test-Path $p) {
      Remove-Item -Force $p -ErrorAction SilentlyContinue
      Write-KitInfo "  removed $name"
    }
  }

  # Leftover portable processes from a previous USB session on this PC
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Path -and (
        $_.Path -like "*\agentmemory-portable\*" -or
        $_.Path -like "*\home\.agentmemory\bin\iii.exe"
      )
    } |
    ForEach-Object {
      Write-KitInfo "  stopping leftover $($_.ProcessName) pid $($_.Id)"
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
}

function Stop-AgentmemoryDocker {
  param(
    [string[]]$ContainerNames
  )

  $names = @($ContainerNames | Where-Object { $_ } | Select-Object -Unique)
  if ($names.Count -eq 0) {
    Write-KitWarn "No Docker containers to stop."
    return $true
  }

  Write-KitInfo "Stopping Docker containers: $($names -join ', ')"
  docker stop @names 2>&1 | ForEach-Object { Write-Host "  $_" }
  if ($LASTEXITCODE -ne 0) {
    Write-KitWarn "docker stop returned $LASTEXITCODE - checking ports anyway..."
  }

  # Best-effort compose down without -v (keeps PC volumes intact)
  $composeCandidates = @(
    (Join-Path $RepoDir "docker-compose.yml"),
    (Join-Path $KitRoot "docker-compose.yml")
  )
  foreach ($compose in $composeCandidates) {
    if (Test-Path $compose) {
      Write-KitInfo "docker compose -f `"$compose`" down (no volume delete)"
      Push-Location (Split-Path -Parent $compose)
      try {
        docker compose -f $compose down 2>&1 | ForEach-Object { Write-Host "  $_" }
      } finally {
        Pop-Location
      }
      break
    }
  }

  Start-Sleep -Seconds 2
  $still = Get-AgentmemoryDockerContainers
  if ($still.Count -gt 0) {
    Write-KitError "Containers still running after cleanup: $($still -join ', ')"
    Write-KitError "Stop them manually, then re-run start.cmd"
    return $false
  }

  Write-KitInfo "Docker conflict cleared. USB data path will be used: $DataDir"
  return $true
}

function Resolve-DockerConflict {
  param(
    [switch]$AutoClean
  )

  $running = Get-AgentmemoryDockerContainers
  if ($running.Count -eq 0) { return $true }

  if ($AutoClean) {
    Write-KitWarn "AutoClean: Docker agentmemory detected - cleaning and continuing..."
    Clear-KitRuntimeState
    if (-not (Stop-AgentmemoryDocker -ContainerNames $running)) { return $false }
    return $true
  }

  Show-DockerConflictMenu -ContainerNames $running

  $choice = ""
  try {
    Write-Host "Digita A, B o C e premi Invio: " -NoNewline -ForegroundColor White
    $choice = [System.Console]::ReadLine()
  } catch {
    Write-KitError "Interactive input unavailable. Re-run with start-clean.cmd for automatic cleanup."
    return $false
  }

  switch -Regex ($choice.Trim().ToUpperInvariant()) {
    "^A" {
      Write-Host ""
      Write-Host "Procedura manuale:" -ForegroundColor Green
      Write-Host "  1. docker stop $($running -join ' ')" -ForegroundColor White
      Write-Host "  2. (opzionale) docker compose down nella cartella del progetto" -ForegroundColor White
      Write-Host "  3. Rilancia start.cmd" -ForegroundColor White
      Write-Host ""
      Write-Host "Premi Invio per chiudere..." -ForegroundColor DarkGray
      try { [void][System.Console]::ReadLine() } catch { Start-Sleep -Seconds 5 }
      return $false
    }
    "^B" {
      Write-Host ""
      Write-Host "Ok: resto su Docker. Non avvio il kit USB." -ForegroundColor DarkYellow
      Write-Host "MCP/Cursor: http://127.0.0.1:3111" -ForegroundColor DarkYellow
      Write-Host ""
      Write-Host "Premi Invio per chiudere..." -ForegroundColor DarkGray
      try { [void][System.Console]::ReadLine() } catch { Start-Sleep -Seconds 5 }
      return $false
    }
    "^C" {
      Write-Host ""
      Write-KitInfo "Opzione C: pulizia automatica in corso..."
      Clear-KitRuntimeState
      if (-not (Stop-AgentmemoryDocker -ContainerNames $running)) {
        Write-Host "Premi Invio per chiudere..." -ForegroundColor DarkGray
        try { [void][System.Console]::ReadLine() } catch { Start-Sleep -Seconds 5 }
        return $false
      }
      Write-KitInfo "Pulizia completata. Avvio del daemon USB..."
      return $true
    }
    default {
      Write-KitError "Scelta non valida ('$choice'). Usa A, B o C."
      Write-Host "Premi Invio per chiudere..." -ForegroundColor DarkGray
      try { [void][System.Console]::ReadLine() } catch { Start-Sleep -Seconds 5 }
      return $false
    }
  }
}

function Assert-NoForeignEngine {
  param(
    [switch]$AutoClean
  )

  if (-not (Resolve-DockerConflict -AutoClean:$AutoClean)) {
    exit 1
  }
}

function Set-PortableRuntimeEnv {
  param(
    [switch]$ForDaemon
  )

  $env:PATH = "$NodeDir;$IiiBinDir;$env:PATH"
  $env:npm_config_cache = Join-Path $PortableDir "npm-cache"

  if ($ForDaemon) {
    $env:USERPROFILE = $HomeDir
    $env:HOME = $HomeDir
    $env:HOMEDRIVE = (Split-Path -Qualifier $HomeDir)
    $env:HOMEPATH = ($HomeDir.Substring($env:HOMEDRIVE.Length))
    $env:APPDATA = Join-Path $HomeDir "AppData\Roaming"
    $env:LOCALAPPDATA = Join-Path $HomeDir "AppData\Local"
    $env:TEMP = Join-Path $HomeDir "Temp"
    $env:TMP = Join-Path $HomeDir "Temp"

    $env:HF_HOME = Join-Path $HomeDir "cache\huggingface"
    $env:TRANSFORMERS_CACHE = Join-Path $HomeDir "cache\transformers"
    $env:XDG_CACHE_HOME = Join-Path $HomeDir "cache"

    $env:AGENTMEMORY_III_VERSION = (Get-KitConfig).IiiVersion
    $env:AGENTMEMORY_URL = "http://127.0.0.1:3111"
    $env:AGENTMEMORY_III_CONFIG = $IiiConfigPath
    $env:AGENTMEMORY_USE_DOCKER = "0"
    $env:AGENTMEMORY_EXPORT_ROOT = Join-Path $AgentmemoryHome "exports"
    $env:SNAPSHOT_DIR = Join-Path $AgentmemoryHome "snapshots"

    foreach ($d in @(
        $env:APPDATA,
        $env:LOCALAPPDATA,
        $env:TEMP,
        $env:HF_HOME,
        $env:TRANSFORMERS_CACHE,
        $env:XDG_CACHE_HOME,
        $AgentmemoryHome,
        $IiiBinDir,
        $DataDir,
        $env:AGENTMEMORY_EXPORT_ROOT,
        $env:SNAPSHOT_DIR
      )) {
      if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
      }
    }
  }
}

function Invoke-AgentmemoryCli {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
  )

  Assert-NodePresent
  Assert-RepoBuilt
  Assert-UsbDataLayout
  # cwd = kit root so iii-config ./data stays on the USB/kit folder
  Set-Location $KitRoot
  & $NodeExe $CliEntry @CliArgs
  return $LASTEXITCODE
}

function Complete-WindowsBuildArtifacts {
  # package.json "build" uses Unix cp/mkdir/true; on Windows cmd that tail fails
  # after tsdown already wrote dist/. Copy the runtime assets the CLI expects.
  $dist = Join-Path $RepoDir "dist"
  if (-not (Test-Path $dist)) {
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
  }
  foreach ($name in @("iii-config.yaml", "iii-config.docker.yaml", "docker-compose.yml", ".env.example")) {
    $src = Join-Path $RepoDir $name
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $dist $name) -Force
    }
  }
  $viewerSrc = Join-Path $RepoDir "src\viewer"
  $viewerDst = Join-Path $dist "viewer"
  if (-not (Test-Path $viewerDst)) {
    New-Item -ItemType Directory -Force -Path $viewerDst | Out-Null
  }
  foreach ($name in @("index.html", "favicon.svg")) {
    $src = Join-Path $viewerSrc $name
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $viewerDst $name) -Force
    }
  }
}

function Invoke-RepoBuild {
  $npmCmd = Join-Path $NodeDir "npm.cmd"
  if (-not (Test-Path $npmCmd)) { throw "npm.cmd not found in portable Node: $npmCmd" }
  Set-Location $RepoDir
  Write-KitInfo "npm run build (tsdown) ..."
  & $npmCmd run build
  $buildCode = $LASTEXITCODE
  Complete-WindowsBuildArtifacts
  if (-not (Test-Path $CliEntry)) {
    throw "Build incomplete: missing $CliEntry (npm exit $buildCode)"
  }
  if ($buildCode -ne 0) {
    Write-KitWarn "npm run build exited $buildCode (Unix post-copy on Windows). Assets repaired; dist\cli.mjs OK."
  }
}

