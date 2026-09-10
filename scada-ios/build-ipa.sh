#!/usr/bin/env bash
# Dựng IPA KHÔNG KÝ từ mã nguồn. Chỉ chạy được trên macOS có Xcode.
#
# Vì sao không ký: ký được cần certificate + provisioning profile của tài khoản
# Apple Developer. Bỏ ký ra khỏi bước build giúp bất kỳ máy macOS nào cũng dựng
# được file, rồi ký lại sau bằng Sideloadly/AltStore (Apple ID miễn phí) hoặc
# bằng CI có sẵn certificate.
set -euo pipefail

APP_NAME="SCADA"
SCHEME="Scada"
PROJECT="Scada.xcodeproj"
OUT_IPA="${APP_NAME}-unsigned.ipa"

command -v xcodebuild >/dev/null 2>&1 || {
  echo "LỖI: không tìm thấy xcodebuild. Máy này phải là macOS và đã cài Xcode." >&2
  exit 1
}

# project.pbxproj được sinh từ project.yml nên không commit vào repo.
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Chưa có xcodegen, đang cài bằng Homebrew..."
  brew install xcodegen
fi

echo "==> Sinh $PROJECT từ project.yml"
xcodegen generate

echo "==> Biên dịch bản Release cho thiết bị thật"
rm -rf build
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

APP_PATH="build/Build/Products/Release-iphoneos/${APP_NAME}.app"
[ -d "$APP_PATH" ] || { echo "LỖI: không thấy $APP_PATH" >&2; exit 1; }

# IPA thực chất là file zip có đúng một thư mục Payload ở gốc.
echo "==> Đóng gói $OUT_IPA"
rm -rf Payload "$OUT_IPA"
mkdir Payload
cp -R "$APP_PATH" Payload/
zip -qry "$OUT_IPA" Payload
rm -rf Payload

echo ""
echo "XONG: $(pwd)/$OUT_IPA"
echo "File này CHƯA ĐƯỢC KÝ. Cài lên máy thật bằng Sideloadly hoặc AltStore"
echo "(đăng nhập Apple ID miễn phí, ứng dụng dùng được 7 ngày rồi ký lại)."
