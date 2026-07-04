$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root "server\server-main"
$WebPort = 52733

$connections = Get-NetTCPConnection -LocalPort $WebPort -State Listen -ErrorAction SilentlyContinue
foreach ($connection in $connections) {
  if ($connection.OwningProcess -gt 0) {
    Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
  }
}

Push-Location $ServerDir
try {
  docker compose -f docker-compose.local.yml down | Out-Host
} finally {
  Pop-Location
}

Write-Host "DLR local app stopped. PocketBase data volume was not deleted."
