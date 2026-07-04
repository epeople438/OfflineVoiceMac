#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OfflineVoiceMac"
BUNDLE_ID="${OFFLINE_VOICE_BUNDLE_ID:-org.offlinevoice.mac}"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
BASE_MODEL_SOURCE="${OFFLINE_VOICE_BASE_MODEL:-$HOME/whisper.cpp/models/ggml-base.bin}"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icns"

BREW_BIN="${HOMEBREW_BREW:-$(command -v brew || true)}"

brew_prefix() {
  local formula="$1"
  [[ -n "$BREW_BIN" ]] || return 0
  "$BREW_BIN" --prefix "$formula" 2>/dev/null || true
}

find_first_file() {
  local pattern file
  for pattern in "$@"; do
    for file in $pattern; do
      [[ -f "$file" ]] && { printf '%s\n' "$file"; return 0; }
    done
  done
}

find_ggml_lib() {
  local directory="$1"
  [[ -d "$directory" ]] || return 0
  find "$directory" -maxdepth 1 -type f -name 'libggml.*.dylib' ! -name '*base*' | sort -V | tail -n 1
}

find_ggml_base_lib() {
  local directory="$1"
  [[ -d "$directory" ]] || return 0
  find "$directory" -maxdepth 1 -type f -name 'libggml-base.*.dylib' | sort -V | tail -n 1
}

WHISPER_PREFIX="${OFFLINE_VOICE_WHISPER_PREFIX:-$(brew_prefix whisper-cpp)}"
GGML_PREFIX="${OFFLINE_VOICE_GGML_PREFIX:-$(brew_prefix ggml)}"
LIBOMP_PREFIX="${OFFLINE_VOICE_LIBOMP_PREFIX:-$(brew_prefix libomp)}"
WHISPER_CLI_SOURCE="${OFFLINE_VOICE_WHISPER_CLI:-${WHISPER_PREFIX:+$WHISPER_PREFIX/bin/whisper-cli}}"
LIBWHISPER_SOURCE="${OFFLINE_VOICE_LIBWHISPER:-$(find_first_file "${WHISPER_PREFIX:-/dev/null}/lib/libwhisper."*.dylib "${WHISPER_PREFIX:-/dev/null}/lib/libwhisper.dylib")}"
LIBGGML_SOURCE="${OFFLINE_VOICE_LIBGGML:-$(find_ggml_lib "${GGML_PREFIX:-/dev/null}/lib")}"
LIBGGML_BASE_SOURCE="${OFFLINE_VOICE_LIBGGML_BASE:-$(find_ggml_base_lib "${GGML_PREFIX:-/dev/null}/lib")}"
GGML_LIBEXEC_SOURCE="${OFFLINE_VOICE_GGML_LIBEXEC:-${GGML_PREFIX:+$GGML_PREFIX/libexec}}"
LIBOMP_SOURCE="${OFFLINE_VOICE_LIBOMP:-${LIBOMP_PREFIX:+$LIBOMP_PREFIX/lib/libomp.dylib}}"

cd "$ROOT_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES/models" "$APP_RESOURCES/bin" "$APP_RESOURCES/lib" "$APP_RESOURCES/libexec"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$BASE_MODEL_SOURCE" ]]; then
  cp "$BASE_MODEL_SOURCE" "$APP_RESOURCES/models/ggml-base.bin"
else
  echo "warning: built-in base model not found at $BASE_MODEL_SOURCE" >&2
fi

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
else
  echo "warning: app icon not found at $ICON_SOURCE" >&2
fi

if [[ -f "$WHISPER_CLI_SOURCE" && -f "$LIBWHISPER_SOURCE" && -f "$LIBGGML_SOURCE" && -f "$LIBGGML_BASE_SOURCE" ]]; then
  cp "$WHISPER_CLI_SOURCE" "$APP_RESOURCES/bin/whisper-cli"
  cp "$LIBWHISPER_SOURCE" "$APP_RESOURCES/lib/libwhisper.1.dylib"
  cp "$LIBGGML_SOURCE" "$APP_RESOURCES/lib/libggml.0.dylib"
  cp "$LIBGGML_BASE_SOURCE" "$APP_RESOURCES/lib/libggml-base.0.dylib"
  [[ -f "$LIBOMP_SOURCE" ]] && cp "$LIBOMP_SOURCE" "$APP_RESOURCES/lib/libomp.dylib"
  if [[ -d "$GGML_LIBEXEC_SOURCE" ]]; then
    cp "$GGML_LIBEXEC_SOURCE"/*.so "$APP_RESOURCES/libexec/" 2>/dev/null || true
  fi
  chmod +x "$APP_RESOURCES/bin/whisper-cli"

  install_name_tool -id "@rpath/libwhisper.1.dylib" "$APP_RESOURCES/lib/libwhisper.1.dylib"
  install_name_tool -id "@rpath/libggml.0.dylib" "$APP_RESOURCES/lib/libggml.0.dylib"
  install_name_tool -id "@rpath/libggml-base.0.dylib" "$APP_RESOURCES/lib/libggml-base.0.dylib"
  [[ -f "$APP_RESOURCES/lib/libomp.dylib" ]] && install_name_tool -id "@rpath/libomp.dylib" "$APP_RESOURCES/lib/libomp.dylib"

  if [[ -n "$GGML_PREFIX" ]]; then
    install_name_tool -change "$GGML_PREFIX/lib/libggml.0.dylib" "@rpath/libggml.0.dylib" "$APP_RESOURCES/bin/whisper-cli" 2>/dev/null || true
    install_name_tool -change "$GGML_PREFIX/lib/libggml-base.0.dylib" "@rpath/libggml-base.0.dylib" "$APP_RESOURCES/bin/whisper-cli" 2>/dev/null || true
    install_name_tool -change "$GGML_PREFIX/lib/libggml.0.dylib" "@rpath/libggml.0.dylib" "$APP_RESOURCES/lib/libwhisper.1.dylib" 2>/dev/null || true
    install_name_tool -change "$GGML_PREFIX/lib/libggml-base.0.dylib" "@rpath/libggml-base.0.dylib" "$APP_RESOURCES/lib/libwhisper.1.dylib" 2>/dev/null || true
    install_name_tool -change "$GGML_PREFIX/lib/libggml-base.0.dylib" "@rpath/libggml-base.0.dylib" "$APP_RESOURCES/lib/libggml.0.dylib" 2>/dev/null || true
  fi
  if [[ -n "$WHISPER_PREFIX" ]]; then
    install_name_tool -change "$WHISPER_PREFIX/lib/libwhisper.1.dylib" "@rpath/libwhisper.1.dylib" "$APP_RESOURCES/bin/whisper-cli" 2>/dev/null || true
  fi

  for plugin in "$APP_RESOURCES"/libexec/*.so; do
    [[ -f "$plugin" ]] || continue
    [[ -n "$GGML_PREFIX" ]] && install_name_tool -change "$GGML_PREFIX/lib/libggml-base.0.dylib" "@rpath/libggml-base.0.dylib" "$plugin" 2>/dev/null || true
    [[ -n "$LIBOMP_PREFIX" ]] && install_name_tool -change "$LIBOMP_PREFIX/lib/libomp.dylib" "@rpath/libomp.dylib" "$plugin" 2>/dev/null || true
  done
else
  echo "warning: bundled whisper-cli dependencies were not found; app will use system whisper-cli path" >&2
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>离线语音</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>用于录制语音并在本机通过 whisper.cpp 转写为文本。</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  find "$APP_RESOURCES/lib" "$APP_RESOURCES/libexec" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 | xargs -0 -I{} codesign --force --sign - "{}"
  [[ -f "$APP_RESOURCES/bin/whisper-cli" ]] && codesign --force --sign - "$APP_RESOURCES/bin/whisper-cli"
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --build-only|build-only)
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
