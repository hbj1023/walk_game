$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ClientDir = Join-Path $Root "client\client-main"
$LogDir = Join-Path $Root "logs"
$Flutter = Join-Path $Root "..\tools\flutter\bin\flutter.bat"

$WebPort = 52733
$ProdApiBaseUrl = "http://15.165.116.173:8080"

function Stop-WebServerPort {
  param([int]$Port)
  $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  foreach ($connection in $connections) {
    if ($connection.OwningProcess -gt 0) {
      Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
    }
  }
}

if (!(Test-Path $Flutter)) {
  throw "Flutter was not found at $Flutter"
}

try {
  Invoke-WebRequest -UseBasicParsing -Uri "$ProdApiBaseUrl/main" -TimeoutSec 10 | Out-Null
} catch {
  $statusCode = $_.Exception.Response.StatusCode.value__
  if ($statusCode -ne 401) {
    throw "Production API is not reachable at $ProdApiBaseUrl"
  }
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Stop-WebServerPort -Port $WebPort
Start-Sleep -Seconds 1

$out = Join-Path $LogDir "flutter-web-$WebPort-prod.out.log"
$err = Join-Path $LogDir "flutter-web-$WebPort-prod.err.log"
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
    "--dart-define=API_BASE_URL=$ProdApiBaseUrl"
  ) `
  -WorkingDirectory $ClientDir `
  -WindowStyle Hidden `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err

$deadline = (Get-Date).AddSeconds(90)
while ($true) {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$WebPort" -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
      break
    }
  } catch {}

  if ((Get-Date) -gt $deadline) {
    throw "Timed out waiting for Flutter web on port $WebPort. Check $out and $err"
  }
  Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "DLR web app is running against production API."
Write-Host "App: http://127.0.0.1:$WebPort"
Write-Host "API: $ProdApiBaseUrl"
Write-Host ""
Write-Host "Refresh the page, then log in with the production account."
