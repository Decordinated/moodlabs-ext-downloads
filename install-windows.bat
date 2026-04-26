@echo off
setlocal
title MoodLabs Extension Installer

set "PS_URL=https://decordinated.github.io/moodlabs-ext-downloads/install.ps1"
set "PS_LOCAL=%TEMP%\moodlabs-install-%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%PS_LOCAL%' -UseBasicParsing } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'MoodLabs 설치 오류'); exit 1 }"

if not exist "%PS_LOCAL%" (
  echo [오류] 설치 스크립트를 다운로드하지 못했습니다.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_LOCAL%"
set EXITCODE=%ERRORLEVEL%

del "%PS_LOCAL%" >nul 2>&1

if not "%EXITCODE%"=="0" (
  echo.
  echo 설치가 정상적으로 끝나지 않았습니다. 위 로그를 확인해주세요.
  pause
)

endlocal
exit /b %EXITCODE%
