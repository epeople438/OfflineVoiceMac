#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OfflineVoiceMac"
VOLUME_NAME="离线语音"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_STAGE="$DIST_DIR/dmg-stage"
DMG_PATH="$DIST_DIR/OfflineVoiceMac.dmg"

cd "$ROOT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --build-only

rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$DMG_STAGE/$APP_NAME.app"
fi

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
ls -lh "$DMG_PATH"
