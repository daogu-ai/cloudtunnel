#!/bin/bash
# 编译并打包成可双击运行的 CloudTunnel.app（纯菜单栏，无 Dock 图标）。
set -euo pipefail
cd "$(dirname "$0")"

APP="CloudTunnel.app"
BIN_NAME="CloudTunnel"

echo "==> swift build -c release"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"

echo "==> 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>CloudTunnel</string>
    <key>CFBundleDisplayName</key>     <string>CloudTunnel</string>
    <key>CFBundleIdentifier</key>      <string>com.wuji.cloudtunnel</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>CloudTunnel</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>            <true/>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
    <key>CFBundleAllowMixedLocalizations</key><true/>
</dict>
</plist>
PLIST

# 签名：设了 CODESIGN_IDENTITY 用 Developer ID + hardened runtime（可公证）；
# 否则 ad-hoc 自签（仅本机可用，分发需用户解除隔离）。
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "==> Developer ID 签名: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --sign "$CODESIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP" || true
else
  echo "==> ad-hoc 签名（未公证；分发时用户需解除隔离）"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "==> 完成: $(pwd)/$APP"
echo "    运行: open $APP   （图标出现在右上角菜单栏）"
