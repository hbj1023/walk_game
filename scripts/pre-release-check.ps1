param(
  [string]$FlutterPath = "",
  [string]$ApiBaseUrl = "https://walk-master.com",
  [switch]$AllowDirty,
  [switch]$SkipAndroidBuild
)

$ErrorActionPreference = "Stop"
$SourceRoot = Split-Path -Parent $PSScriptRoot
$ArtifactDir = Join-Path $SourceRoot "artifacts\release"
$BuildRoot = $SourceRoot
$TemporaryWorktree = $null

function Resolve-Flutter {
  param([string]$RequestedPath)

  $candidates = @($RequestedPath)
  if ($env:FLUTTER_ROOT) {
    $candidates += Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
  }
  $candidates += Join-Path $SourceRoot "..\tools\flutter\bin\flutter.bat"
  $candidates += Join-Path $SourceRoot "tools\flutter\bin\flutter.bat"
  $candidates = $candidates | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $command = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  throw "Flutter를 찾지 못했습니다. -FlutterPath 또는 FLUTTER_ROOT를 지정하세요."
}

function Invoke-Checked {
  param(
    [string]$Label,
    [scriptblock]$Command
  )
  Write-Host ""
  Write-Host "[$Label]" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label 실패 (종료 코드: $LASTEXITCODE)"
  }
}

function Copy-LocalAndroidSecrets {
  param(
    [string]$FromRoot,
    [string]$ToRoot
  )

  $sourceAndroid = Join-Path $FromRoot "client\client-main\android"
  $targetAndroid = Join-Path $ToRoot "client\client-main\android"
  foreach ($name in @("key.properties", "local.properties")) {
    $source = Join-Path $sourceAndroid $name
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination (Join-Path $targetAndroid $name) -Force
    }
  }

  $sourceApp = Join-Path $sourceAndroid "app"
  $targetApp = Join-Path $targetAndroid "app"
  Get-ChildItem -LiteralPath $sourceApp -File |
    Where-Object { $_.Extension -in @(".jks", ".keystore") } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $targetApp -Force }
}

if (!(Test-Path -LiteralPath (Join-Path $SourceRoot ".git"))) {
  throw "저장소 루트가 아닙니다: $SourceRoot"
}

$dirty = & git -C $SourceRoot status --porcelain
if ($LASTEXITCODE -ne 0) { throw "Git 상태를 확인하지 못했습니다." }
if ($dirty -and !$AllowDirty) {
  throw "커밋되지 않은 변경이 있습니다. 커밋하거나 검증 목적이면 -AllowDirty를 사용하세요."
}

$requiredSourceFiles = @(
  "client/client-main/android/key.properties",
  "client/client-main/web/privacy.html",
  "client/client-main/web/delete-account.html",
  "docs/privacy-policy-ko.md",
  "docs/play-console-declarations-ko.md"
)
foreach ($relativePath in $requiredSourceFiles) {
  if (!(Test-Path -LiteralPath (Join-Path $SourceRoot $relativePath))) {
    throw "필수 파일 누락: $relativePath"
  }
}

$Flutter = Resolve-Flutter -RequestedPath $FlutterPath
Write-Host "Flutter: $Flutter"

$needsAsciiWorktree = $SourceRoot -match '[^\x00-\x7F]'
if ($needsAsciiWorktree) {
  if ($dirty) {
    throw "한글 경로에서는 깨끗한 커밋으로만 영문 임시 작업공간 검증을 실행할 수 있습니다. 먼저 변경을 커밋하세요."
  }
  $TemporaryWorktree = Join-Path ([System.IO.Path]::GetTempPath()) "walkmaster-release-$PID"
  if (Test-Path -LiteralPath $TemporaryWorktree) {
    throw "임시 작업공간이 이미 존재합니다: $TemporaryWorktree"
  }
  Invoke-Checked "영문 임시 작업공간 생성" {
    & git -C $SourceRoot worktree add --detach $TemporaryWorktree HEAD
  }
  Copy-LocalAndroidSecrets -FromRoot $SourceRoot -ToRoot $TemporaryWorktree
  $BuildRoot = $TemporaryWorktree
}

try {
  $ClientDir = Join-Path $BuildRoot "client\client-main"
  # Windows Application Control can block Go test executables created below
  # %TEMP%. The server sources do not need the ASCII-only Flutter worktree.
  $ServerDir = Join-Path $SourceRoot "server\server-main"

  $gradle = Get-Content -Raw -LiteralPath (Join-Path $ClientDir "android\app\build.gradle.kts")
  if ($gradle -notmatch 'applicationId\s*=\s*"com\.hbj1023\.walkmaster"') {
    throw "Android applicationId가 com.hbj1023.walkmaster가 아닙니다."
  }

  $manifest = Get-Content -Raw -LiteralPath (Join-Path $ClientDir "android\app\src\main\AndroidManifest.xml")
  if ($manifest -notmatch 'usesCleartextTraffic="false"') {
    throw "Android 평문 HTTP 차단이 설정되지 않았습니다."
  }

  Push-Location $ClientDir
  try {
    Invoke-Checked "Flutter analyze" { & $Flutter analyze }
    Invoke-Checked "Flutter test" { & $Flutter test }
    if (!$SkipAndroidBuild) {
      Invoke-Checked "Android app bundle" {
        & $Flutter build appbundle --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
      }
    }
  } finally {
    Pop-Location
  }

  Push-Location $ServerDir
  try {
    New-Item -ItemType Directory -Force -Path ".gocache" | Out-Null
    New-Item -ItemType Directory -Force -Path ".gotmp" | Out-Null
    $env:GOCACHE = (Resolve-Path ".gocache").Path
    $env:GOTMPDIR = (Resolve-Path ".gotmp").Path
    Invoke-Checked "Go test" { & go test ./... }
  } finally {
    Pop-Location
  }

  if (!$SkipAndroidBuild) {
    $pubspec = Get-Content -Raw -LiteralPath (Join-Path $ClientDir "pubspec.yaml")
    $versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([^\r\n]+)$')
    if (!$versionMatch.Success) { throw "pubspec 버전을 찾지 못했습니다." }
    $version = $versionMatch.Groups[1].Value.Trim().Replace("+", "-")
    $sourceAab = Join-Path $ClientDir "build\app\outputs\bundle\release\app-release.aab"
    if (!(Test-Path -LiteralPath $sourceAab)) { throw "AAB 출력 파일이 없습니다: $sourceAab" }

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
    $targetAab = Join-Path $ArtifactDir "WalkMaster-$version.aab"
    Copy-Item -LiteralPath $sourceAab -Destination $targetAab -Force
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $targetAab
    Set-Content -LiteralPath "$targetAab.sha256" -Value "$($hash.Hash.ToLowerInvariant())  $(Split-Path -Leaf $targetAab)" -Encoding ascii
    Write-Host "AAB: $targetAab" -ForegroundColor Green
    Write-Host "SHA-256: $($hash.Hash)" -ForegroundColor Green
  }
} finally {
  if ($TemporaryWorktree) {
    & git -C $SourceRoot worktree remove --force $TemporaryWorktree
    if ($LASTEXITCODE -ne 0) {
      & git -C $SourceRoot worktree prune

      $resolvedWorktree = [System.IO.Path]::GetFullPath($TemporaryWorktree)
      $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
      $isExpectedTemp = $resolvedWorktree.StartsWith(
        $resolvedTempRoot,
        [System.StringComparison]::OrdinalIgnoreCase
      ) -and (Split-Path -Leaf $resolvedWorktree).StartsWith("walkmaster-release-")

      if ($isExpectedTemp -and (Test-Path -LiteralPath $resolvedWorktree)) {
        Remove-Item -LiteralPath ("\\?\" + $resolvedWorktree) -Recurse -Force
      }
    }
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "임시 작업공간을 자동 정리하지 못했습니다: $TemporaryWorktree"
    }
  }
}

try {
  $rootResponse = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/" -TimeoutSec 15
  if ($rootResponse.StatusCode -ne 200) { throw "홈 상태 코드 $($rootResponse.StatusCode)" }
  try {
    Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/main" -TimeoutSec 15 | Out-Null
    throw "인증 없는 /main 요청이 성공했습니다."
  } catch {
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -ne 401) { throw }
  }
  Write-Host "공개 서버: 홈 200, 인증 없는 /main 401" -ForegroundColor Green
} catch {
  throw "공개 서버 점검 실패: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "자동 배포 전 점검을 통과했습니다." -ForegroundColor Green
