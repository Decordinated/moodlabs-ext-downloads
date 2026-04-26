#!/usr/bin/env bash
# MoodLabs Extension Installer (macOS)
# Downloads the latest release zip from the public downloads page,
# extracts it to a fixed location, and walks the user through the
# remaining Chrome "Load unpacked" step.

set -euo pipefail

INSTALL_BASE_URL="https://decordinated.github.io/moodlabs-ext-downloads"
INSTALL_DIR="$HOME/Library/Application Support/MoodLabs/extension"
APP_LABEL="MoodLabs 설치 도우미"

cd "$(dirname "$0")"

osa_alert() {
  /usr/bin/osascript \
    -e "display dialog \"$1\" with title \"$APP_LABEL\" buttons {\"확인\"} default button 1" \
    >/dev/null 2>&1 || true
}

osa_error_exit() {
  /usr/bin/osascript \
    -e "display dialog \"$1\" with title \"$APP_LABEL · 오류\" with icon caution buttons {\"닫기\"} default button 1" \
    >/dev/null 2>&1 || true
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || osa_error_exit "필수 도구를 찾지 못했습니다: $1"
}

require_command curl
require_command unzip
require_command shasum
require_command python3

TMP_DIR="$(mktemp -d -t moodlabs-install)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> 배포 정보 가져오는 중: $INSTALL_BASE_URL/manifest.json"
if ! curl -fsSL "$INSTALL_BASE_URL/manifest.json" -o "$TMP_DIR/manifest.json"; then
  osa_error_exit "배포 정보를 가져오지 못했습니다.\n인터넷 연결을 확인해주세요."
fi

read -r VERSION FILE_NAME DOWNLOAD_URL EXPECTED_SHA <<EOF
$(/usr/bin/python3 - "$TMP_DIR/manifest.json" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1], encoding='utf-8'))
versions = manifest.get('versions') or []
if not versions:
    sys.exit(2)
latest = versions[0]
print(latest['version'], latest['fileName'], latest['downloadUrl'], latest['sha256'])
PY
)
EOF

if [ -z "${VERSION:-}" ]; then
  osa_error_exit "manifest.json 파싱에 실패했습니다."
fi

echo "==> 최신 버전: v$VERSION"
echo "==> ZIP 다운로드: $DOWNLOAD_URL"
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$FILE_NAME"; then
  osa_error_exit "ZIP 다운로드에 실패했습니다."
fi

ACTUAL_SHA="$(shasum -a 256 "$TMP_DIR/$FILE_NAME" | awk '{print $1}')"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  osa_error_exit "다운로드한 파일이 손상되었습니다.\nSHA-256 불일치."
fi

echo "==> 압축 해제: $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
unzip -q "$TMP_DIR/$FILE_NAME" -d "$INSTALL_DIR"

# Some zips wrap contents in a single top-level folder. Flatten if so.
shopt -s nullglob
top_entries=("$INSTALL_DIR"/*)
shopt -u nullglob
if [ "${#top_entries[@]}" -eq 1 ] && [ -d "${top_entries[0]}" ]; then
  inner_dir="${top_entries[0]}"
  /bin/mv "$inner_dir"/* "$INSTALL_DIR/" 2>/dev/null || true
  /bin/mv "$inner_dir"/.[!.]* "$INSTALL_DIR/" 2>/dev/null || true
  rmdir "$inner_dir" 2>/dev/null || true
fi

echo -n "$INSTALL_DIR" | /usr/bin/pbcopy || true

/usr/bin/open "$INSTALL_DIR"

if [ -d "/Applications/Google Chrome.app" ]; then
  /usr/bin/open -a "Google Chrome" "chrome://extensions/"
elif [ -d "/Applications/Chromium.app" ]; then
  /usr/bin/open -a Chromium "chrome://extensions/"
elif [ -d "/Applications/Brave Browser.app" ]; then
  /usr/bin/open -a "Brave Browser" "chrome://extensions/"
fi

/usr/bin/open "$INSTALL_BASE_URL/install.html?os=mac&v=$VERSION" 2>/dev/null || true

osa_alert "MoodLabs Extension v$VERSION 준비 완료!\n\n다음 단계:\n1) 열린 Chrome 페이지(chrome://extensions)에서\n   우상단 'Developer mode' 토글을 켜주세요.\n2) 'Load unpacked' 버튼을 클릭.\n3) Finder에서 열린 폴더를 선택하세요.\n   (경로는 클립보드에 복사되어 있어 Cmd+V로 붙여넣어도 됩니다.)\n\n폴더: $INSTALL_DIR"

echo "==> 완료"
