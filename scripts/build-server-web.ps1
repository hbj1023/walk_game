$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ClientDir = Join-Path $Root "client\client-main"
$ServerDir = Join-Path $Root "server\server-main"
$WebDist = Join-Path $ServerDir "web_dist"
$ArtifactDir = Join-Path $Root "artifacts"
$Artifact = Join-Path $ArtifactDir "dlr-web.tar.gz"
$Flutter = Join-Path $Root "..\tools\flutter\bin\flutter.bat"

if (!(Test-Path $Flutter)) {
  throw "Flutter was not found at $Flutter"
}

Push-Location $ClientDir
try {
  & $Flutter build web --release --dart-define=API_BASE_URL=
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter web build failed."
  }

  $BuildId = Get-Date -Format "yyyyMMddHHmmss"
  $MainJs = Join-Path $ClientDir "build\web\main.dart.js"
  $VersionedMainJsName = "main.$BuildId.dart.js"
  $VersionedMainJs = Join-Path $ClientDir "build\web\$VersionedMainJsName"
  Copy-Item -LiteralPath $MainJs -Destination $VersionedMainJs -Force
  $Bootstrap = Join-Path $ClientDir "build\web\flutter_bootstrap.js"
  $BootstrapText = Get-Content -Raw -LiteralPath $Bootstrap
  $BootstrapText = $BootstrapText.Replace('"mainJsPath":"main.dart.js"', '"mainJsPath":"' + $VersionedMainJsName + '"')
  $BootstrapText = [regex]::Replace(
    $BootstrapText,
    '_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[\s\S]*?\}\s*\}\);',
    '_flutter.loader.load({});'
  )
  Set-Content -LiteralPath $Bootstrap -Value $BootstrapText -NoNewline

  $VersionedBootstrapName = "flutter_bootstrap.$BuildId.js"
  $VersionedBootstrap = Join-Path $ClientDir "build\web\$VersionedBootstrapName"
  Copy-Item -LiteralPath $Bootstrap -Destination $VersionedBootstrap -Force
  $IndexHtml = Join-Path $ClientDir "build\web\index.html"
  $IndexHtmlText = Get-Content -Raw -LiteralPath $IndexHtml
  $IndexHtmlText = $IndexHtmlText.Replace('src="flutter_bootstrap.js"', 'src="' + $VersionedBootstrapName + '"')
  Set-Content -LiteralPath $IndexHtml -Value $IndexHtmlText -NoNewline
} finally {
  Pop-Location
}

$resolvedServer = (Resolve-Path $ServerDir).Path
$resolvedWebDist = [System.IO.Path]::GetFullPath($WebDist)
if (!$resolvedWebDist.StartsWith($resolvedServer, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to replace files outside the server workspace."
}

New-Item -ItemType Directory -Force -Path $WebDist, $ArtifactDir | Out-Null
Get-ChildItem -LiteralPath $WebDist -Force |
  Where-Object { $_.Name -ne ".gitignore" } |
  Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $ClientDir "build\web\*") -Destination $WebDist -Recurse -Force

if (Test-Path $Artifact) {
  Remove-Item -LiteralPath $Artifact -Force
}
& tar.exe -czf $Artifact -C $WebDist .
if ($LASTEXITCODE -ne 0) {
  throw "Failed to create $Artifact"
}

Write-Host ""
Write-Host "Server web package is ready."
Write-Host "Web files: $WebDist"
Write-Host "Upload file: $Artifact"
