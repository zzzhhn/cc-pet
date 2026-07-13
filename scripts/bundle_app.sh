#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "${ROOT}/app"
swift build -c release
APP="${ROOT}/ClawPet.app/Contents"
mkdir -p "${APP}/MacOS" "${APP}/Resources"
cp ".build/release/ClawPet" "${APP}/MacOS/ClawPet"
# ship the pet art inside the bundle so a fresh machine has a fallback pet
mkdir -p "${APP}/Resources/pets"
cp -R "${ROOT}/pets/placeholder" "${APP}/Resources/pets/placeholder"
cat > "${APP}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ClawPet</string>
  <key>CFBundleIdentifier</key><string>com.bobby.clawpet</string>
  <key>CFBundleExecutable</key><string>ClawPet</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
echo "built ${ROOT}/ClawPet.app"
