#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Currency Converter"
BIN_NAME="CurrencyConverter"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

cd "$ROOT"
BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Missing binary at $BIN_PATH — run swift build -c release first." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
