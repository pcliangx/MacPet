#!/bin/bash
# mpet .app 打包脚本：release 构建 → 组装 bundle → ad-hoc 签名
# 产出 dist/mpet.app（可双击；daemon 与 cc-watcher 内嵌，首启自动安装 LaunchAgent）
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' Sources/SoulCore/SoulCore.swift)"
APP="dist/mpet.app"

echo "▸ 构建 release（v${VERSION}）…"
swift build -c release 2>&1 | tail -1

echo "▸ 组装 ${APP} …"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp .build/release/MpetApp          "${APP}/Contents/MacOS/MpetApp"
cp .build/release/mpet-soul        "${APP}/Contents/Resources/mpet-soul"
cp .build/release/mpet-cc-watcher  "${APP}/Contents/Resources/mpet-cc-watcher"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>        <string>MpetApp</string>
    <key>CFBundleIdentifier</key>        <string>com.mpet.app</string>
    <key>CFBundleName</key>              <string>mpet</string>
    <key>CFBundleDisplayName</key>       <string>mpet</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key>           <string>${VERSION}</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

echo "▸ ad-hoc 签名…"
codesign --force --deep --sign - "${APP}"

echo "✅ 完成：${APP}"
echo "   双击运行，或：open ${APP}"
echo "   （LSUIElement=true：无 Dock 图标，宠物窗口 + 菜单栏 🐾 常驻）"
