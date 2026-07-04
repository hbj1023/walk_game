$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root "server\server-main"

Write-Host "Docker containers:"
Push-Location $ServerDir
try {
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-Host
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "Ports:"
Get-NetTCPConnection -LocalPort 52733,8082,8090 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,State,OwningProcess |
  Format-Table |
  Out-Host

Write-Host "Health:"
try {
  $pb = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8090/api/health" -TimeoutSec 5
  Write-Host "PocketBase: $($pb.StatusCode)"
} catch {
  Write-Host "PocketBase: not reachable"
}

try {
  Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:8082/main" -TimeoutSec 5 | Out-Null
  Write-Host "API: reachable"
} catch {
  $statusCode = $_.Exception.Response.StatusCode.value__
  if ($statusCode -eq 401) {
    Write-Host "API: reachable (401 without login token is expected)"
  } else {
    Write-Host "API: not reachable"
  }
}
