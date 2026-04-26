# MoodLabs Extension Installer (Windows)
# Downloads the latest release zip from the public downloads page,
# extracts it to %LOCALAPPDATA%\MoodLabs\extension, and opens
# Chrome + the install guide page so the user can finish in 2-3 clicks.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$InstallBaseUrl = 'https://decordinated.github.io/moodlabs-ext-downloads'
$InstallDir = Join-Path $env:LOCALAPPDATA 'MoodLabs\extension'

Add-Type -AssemblyName PresentationFramework | Out-Null

function Show-Info($msg) {
  [System.Windows.MessageBox]::Show($msg, 'MoodLabs 설치 도우미', 'OK', 'Information') | Out-Null
}

function Show-ErrorAndExit($msg) {
  [System.Windows.MessageBox]::Show($msg, 'MoodLabs 설치 오류', 'OK', 'Error') | Out-Null
  exit 1
}

function Find-Chrome {
  $candidates = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "${env:LocalAppData}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles}\BraveSoftware\Brave-Browser\Application\brave.exe",
    "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe"
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

$tempDir = Join-Path $env:TEMP ("moodlabs-install-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
  Write-Host "==> 배포 정보 가져오는 중: $InstallBaseUrl/manifest.json"
  try {
    $manifest = Invoke-RestMethod -Uri "$InstallBaseUrl/manifest.json" -UseBasicParsing
  } catch {
    Show-ErrorAndExit "배포 정보를 가져오지 못했습니다.`n인터넷 연결을 확인해주세요.`n`n$($_.Exception.Message)"
  }

  if (-not $manifest.versions -or $manifest.versions.Count -eq 0) {
    Show-ErrorAndExit "배포된 버전이 없습니다."
  }

  $latest = $manifest.versions[0]
  $version = $latest.version
  $fileName = $latest.fileName
  $downloadUrl = $latest.downloadUrl
  $expectedSha = $latest.sha256.ToLower()

  $zipPath = Join-Path $tempDir $fileName
  Write-Host "==> 최신 버전: v$version"
  Write-Host "==> ZIP 다운로드: $downloadUrl"
  try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
  } catch {
    Show-ErrorAndExit "ZIP 다운로드에 실패했습니다.`n`n$($_.Exception.Message)"
  }

  $actualSha = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower()
  if ($actualSha -ne $expectedSha) {
    Show-ErrorAndExit "다운로드한 파일이 손상되었습니다.`nSHA-256 불일치."
  }

  Write-Host "==> 압축 해제: $InstallDir"
  if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
  }
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force

  # Flatten if zip wraps everything in a single top-level folder
  $topEntries = Get-ChildItem -Force $InstallDir
  if ($topEntries.Count -eq 1 -and $topEntries[0].PSIsContainer) {
    $inner = $topEntries[0].FullName
    Get-ChildItem -Force $inner | ForEach-Object {
      Move-Item -Force -Path $_.FullName -Destination $InstallDir
    }
    Remove-Item -Force -Recurse $inner
  }

  Set-Clipboard -Value $InstallDir

  Start-Process explorer.exe $InstallDir | Out-Null

  $chrome = Find-Chrome
  if ($chrome) {
    Start-Process $chrome -ArgumentList 'chrome://extensions/' | Out-Null
  }

  Start-Process "$InstallBaseUrl/install.html?os=win&v=$version" | Out-Null

  Show-Info @"
MoodLabs Extension v$version 준비 완료!

다음 단계:
1) 열린 Chrome 페이지(chrome://extensions)에서
   우상단 'Developer mode' 토글을 켜주세요.
2) 'Load unpacked' 버튼을 클릭.
3) 탐색기에서 열린 폴더를 선택하세요.
   (경로는 클립보드에 복사되어 있어 Ctrl+V로 붙여넣어도 됩니다.)

폴더: $InstallDir
"@

  Write-Host '==> 완료'
} finally {
  Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}
