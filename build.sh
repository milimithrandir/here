#!/bin/bash
# Build Here.app and install it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/Here.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"
# Works around the duplicate SwiftBridging modulemap in some Command Line Tools installs.
mkdir -p toolfix && : > toolfix/empty.modulemap
cat > toolfix/overlay.yaml <<EOF2
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file", "name": "/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap", "external-contents": "$PWD/toolfix/empty.modulemap" } ] }
EOF2
FLAGS=(-vfsoverlay toolfix/overlay.yaml -Xcc -ivfsoverlay -Xcc toolfix/overlay.yaml -O -swift-version 5)
swiftc "${FLAGS[@]}" -target arm64-apple-macos14 -o build/Here-arm64 Sources/*.swift
swiftc "${FLAGS[@]}" -target x86_64-apple-macos14 -o build/Here-x86_64 Sources/*.swift
lipo -create build/Here-arm64 build/Here-x86_64 -output "$APP/Contents/MacOS/Here"
cp Info.plist "$APP/Contents/"
codesign --force -s - "$APP"
mkdir -p dist && rm -f dist/Here.zip && ditto -c -k --keepParent "$APP" dist/Here.zip
[ "${1:-}" = "--no-install" ] && { echo "Built dist/Here.zip"; exit 0; }
mkdir -p ~/Applications
pkill -x Here || true
rm -rf ~/Applications/Here.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/Here.app"
