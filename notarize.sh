#!/bin/bash
# 公证已签名的 CloudTunnel.app，staple 票据，并重建可上传的发布 zip。
# 前置：先用 Developer ID 签名构建：
#   CODESIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" ./build-app.sh
# 并一次性存好凭证：
#   xcrun notarytool store-credentials <profile> --apple-id ... --team-id ... --password <app-specific>
#
# 用法: ./notarize.sh [keychain-profile]   (默认 profile: cloudtunnel-notary)
set -euo pipefail
cd "$(dirname "$0")"

APP="CloudTunnel.app"
PROFILE="${1:-cloudtunnel-notary}"
VERSION="${VERSION:-1.0.0}"
OUT="dist/CloudTunnel-${VERSION}-macos-arm64.zip"
TMP="dist/CloudTunnel-notarize.zip"

[[ -d "$APP" ]] || { echo "找不到 $APP，请先 ./build-app.sh"; exit 1; }
mkdir -p dist

echo "==> 打包提交公证"
ditto -c -k --keepParent "$APP" "$TMP"
xcrun notarytool submit "$TMP" --keychain-profile "$PROFILE" --wait

echo "==> staple 票据到 .app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> 重建发布 zip: $OUT"
rm -f "$OUT" "$TMP"
ditto -c -k --keepParent "$APP" "$OUT"
echo "完成。可上传: $OUT"
