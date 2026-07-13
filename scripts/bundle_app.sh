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
# Sign with the stable self-signed identity if present, so macOS TCC (Input Monitoring) keeps the
# grant across rebuilds. Falls back to ad-hoc (which re-prompts each build) when it's absent.
IDENTITY="ClawPet Dev"
KC="${HOME}/Library/Keychains/clawpet-signing.keychain-db"
if security find-identity -p codesigning "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
  security unlock-keychain -p clawpet "$KC" 2>/dev/null || true
  codesign --force --deep -s "$IDENTITY" "${ROOT}/ClawPet.app" && echo "signed with '$IDENTITY'"
else
  echo "no stable identity; app is ad-hoc — run scripts/make_signing_cert.sh to stop Input Monitoring re-prompts"
fi

echo "built ${ROOT}/ClawPet.app"
