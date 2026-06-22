#!/bin/bash
# Build Release, install to /Applications, and sign with the local self-signed identity.
# Signing with a stable cert is what makes macOS TCC remember the Accessibility / Screen
# Recording grants across rebuilds (an unsigned/linker-signed build is re-prompted forever).
set -euo pipefail

cd "$(dirname "$0")/.."

APP_DEST="/Applications/AltTab.app"
SIGN_IDENTITY="AltTab Local Signing"
SIGN_KEYCHAIN="$HOME/Library/Keychains/alttab-signing.keychain-db"

echo "==> Building Release"
xcodebuild \
  -project alt-tab-macos.xcodeproj \
  -scheme Release \
  -configuration Release \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

BUILT_APP="DerivedData/Build/Products/Release/AltTab.app"

echo "==> Quitting any running AltTab"
pkill -x AltTab 2>/dev/null || true
sleep 1

echo "==> Installing to $APP_DEST"
rm -rf "$APP_DEST"
ditto "$BUILT_APP" "$APP_DEST"

echo "==> Signing with '$SIGN_IDENTITY'"
security unlock-keychain -p alttab "$SIGN_KEYCHAIN"
codesign --force --deep --options runtime \
  --entitlements alt_tab_macos.entitlements \
  --sign "$SIGN_IDENTITY" --keychain "$SIGN_KEYCHAIN" \
  "$APP_DEST"
codesign --verify --deep --strict "$APP_DEST"

echo "==> Launching"
open -a "$APP_DEST"

echo "Done. If macOS asks for permissions, grant them once; the stable signature makes them stick."
