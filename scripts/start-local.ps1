param(
  [switch]$RestartFlutter,
  [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root "server\server-main"
$ClientDir = Join-Path $Root "client\client-main"
$LogDir = Join-Path $Root "logs"
$Flutter = Join-Path $Root "..\tools\flutter\bin\flutter.bat"

$ApiPort = 8082
$PocketBasePort = 8090
$WebPort = 52733

function Test-PortListening {
  param([int]$Port)
  return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Wait-Http {
  param(
    [string]$Uri,
    [int[]]$OkStatusCodes = @(200),
    [int]$TimeoutSeconds = 45
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 5
      if ($OkStatusCodes -contains [int]$response.StatusCode) {
        return
      }
    } catch {
      $statusCode = $_.Exception.Response.StatusCode.value__
      if ($OkStatusCodes -contains [int]$statusCode) {
        return
      }
    }
    Start-Sleep -Seconds 1
  } while ((Get-Date) -lt $deadline)

  throw "Timed out waiting for $Uri"
}

function Stop-WebServerPort {
  param([int]$Port)
  $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  foreach ($connection in $connections) {
    if ($connection.OwningProcess -gt 0) {
      Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
    }
  }
}

function Remove-ContainerIfExists {
  param([string]$Name)
  $existing = docker ps -a --filter "name=^/$Name$" --format "{{.Names}}"
  if ($existing -contains $Name) {
    docker rm -f $Name | Out-Host
  }
}

function Test-ContainerRunning {
  param([string]$Name)
  $state = docker inspect -f "{{.State.Running}}" $Name 2>$null
  return $state -eq "true"
}

if (!(Test-Path $Flutter)) {
  throw "Flutter was not found at $Flutter"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Push-Location $ServerDir
try {
  Remove-ContainerIfExists -Name "auth-api-fresh"
  Remove-ContainerIfExists -Name "pocketbase-fresh"

  $dockerHealthy = $false
  if (!$Rebuild -and (Test-ContainerRunning -Name "pocketbase") -and (Test-ContainerRunning -Name "auth-api")) {
    try {
      Wait-Http -Uri "http://127.0.0.1:$PocketBasePort/api/health" -OkStatusCodes @(200) -TimeoutSeconds 5
      Wait-Http -Uri "http://127.0.0.1:$ApiPort/main" -OkStatusCodes @(200, 401) -TimeoutSeconds 5
      $dockerHealthy = $true
      Write-Host "Local Docker containers are already running; keeping them up."
    } catch {
      $dockerHealthy = $false
    }
  }

  if (!$dockerHealthy) {
    docker compose -f docker-compose.local.yml up -d --build | Out-Host
  }
} finally {
  Pop-Location
}

Wait-Http -Uri "http://127.0.0.1:$PocketBasePort/api/health" -OkStatusCodes @(200)
Wait-Http -Uri "http://127.0.0.1:$ApiPort/main" -OkStatusCodes @(200, 401)

if ($RestartFlutter) {
  Stop-WebServerPort -Port $WebPort
  Start-Sleep -Seconds 1
}

if (!(Test-PortListening -Port $WebPort)) {
  $out = Join-Path $LogDir "flutter-web-$WebPort.out.log"
  $err = Join-Path $LogDir "flutter-web-$WebPort.err.log"
  $env:Path = (Split-Path $Flutter -Parent) + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Program Files\Git\cmd"

  Start-Process `
    -FilePath $Flutter `
    -ArgumentList @(
      "run",
      "-d",
      "web-server",
      "--web-hostname",
      "127.0.0.1",
      "--web-port",
      "$WebPort",
      "--dart-define=API_BASE_URL=http://localhost:$ApiPort"
    ) `
    -WorkingDirectory $ClientDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err

  $deadline = (Get-Date).AddSeconds(90)
  while (!(Test-PortListening -Port $WebPort)) {
    if ((Get-Date) -gt $deadline) {
      throw "Timed out waiting for Flutter web on port $WebPort. Check $out and $err"
    }
    Start-Sleep -Seconds 1
  }
}

Write-Host ""
Write-Host "DLR local app is running."
Write-Host "App:        http://127.0.0.1:$WebPort"
Write-Host "API:        http://127.0.0.1:$ApiPort"
Write-Host "PocketBase: http://127.0.0.1:$PocketBasePort"
Write-Host ""
Write-Host "Use scripts\stop-local.ps1 only when you intentionally want to stop it."
