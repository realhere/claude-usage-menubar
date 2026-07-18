#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ClaudeUsage"
LABEL="local.claudeusage.menubar"
APP_DIR="$HOME/Applications/$APP_NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DATA_DIR="$HOME/ClaudeUsage"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking prerequisites"
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: this app is macOS only."; exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
  echo "Error: swiftc not found. Install Xcode Command Line Tools first:"
  echo "    xcode-select --install"
  exit 1
fi

echo "==> Building $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
swiftc -O "$SCRIPT_DIR/main.swift" -o "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/usage_helper.py" "$APP_DIR/Contents/Resources/usage_helper.py"
cp "$SCRIPT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>Claude Usage</string>
    <key>CFBundleIdentifier</key><string>$LABEL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "==> Creating data directory ($DATA_DIR)"
mkdir -p "$DATA_DIR"

echo "==> Installing LaunchAgent (auto-start at login)"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$APP_DIR/Contents/MacOS/$APP_NAME</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
AGENT

UID_="$(id -u)"
launchctl bootout "gui/$UID_/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_" "$PLIST"

echo ""
echo "Done! Look for the bar-chart icon in your menu bar (top-right)."
echo "On first launch macOS may ask for keychain access to read the Claude"
echo "desktop app's cookies - click Allow."
echo ""
echo "Uninstall anytime with:  ./uninstall.sh"
