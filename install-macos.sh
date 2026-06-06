#!/usr/bin/env bash
#
# Installs "Pipes.app" into ~/Applications — a fullscreen launcher for the 3D Pipes
# animation in this folder. Re-run any time to rebuild. Uninstall: delete the app
# (the script prints the exact path at the end).
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML="$REPO_DIR/index.html"
APP="$HOME/Applications/Pipes.app"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -f "$HTML" ] || { echo "error: index.html not found next to this script ($HTML)" >&2; exit 1; }

echo "Installing Pipes.app  ->  $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --- Info.plist ---
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pipes</string>
  <key>CFBundleDisplayName</key><string>Pipes</string>
  <key>CFBundleIdentifier</key><string>io.github.pipes.screensaver</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>Pipes</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# --- launcher ---
if [ -x "$CHROME" ]; then
  # Best path: Chrome kiosk = true fullscreen, loads the local files offline.
  cat > "$APP/Contents/MacOS/Pipes" <<LAUNCH
#!/bin/bash
# 3D Pipes — fullscreen. Cmd+Q to quit.
exec "$CHROME" \\
  --user-data-dir="\$HOME/.pipes-kiosk" \\
  --no-first-run --no-default-browser-check \\
  --disable-session-crashed-bubble --disable-infobars \\
  --allow-file-access-from-files \\
  --kiosk --app="file://$HTML"
LAUNCH
  MODE="Google Chrome, fullscreen kiosk (offline)"
else
  # Fallback (no Chrome): serve locally so ES modules load, open default browser.
  cat > "$APP/Contents/MacOS/Pipes" <<LAUNCH
#!/bin/bash
# 3D Pipes — no Chrome found, so serve locally and open the default browser.
PORT=8765
if ! curl -s -o /dev/null "http://127.0.0.1:\$PORT/index.html"; then
  ( cd "$REPO_DIR" && exec python3 -m http.server \$PORT >/dev/null 2>&1 ) &
  sleep 1
fi
open "http://127.0.0.1:\$PORT/index.html"
LAUNCH
  MODE="default browser via local server (install Google Chrome for true fullscreen)"
fi
chmod +x "$APP/Contents/MacOS/Pipes"

# --- icon (build AppIcon.icns from icon.png, preserving transparency) ---
if [ -f "$REPO_DIR/icon.png" ] && command -v iconutil >/dev/null 2>&1; then
  SET="$(mktemp -d)/Pipes.iconset"; mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s"       "$REPO_DIR/icon.png" --out "$SET/icon_${s}x${s}.png"     >/dev/null
    sips -z "$((s*2))" "$((s*2))" "$REPO_DIR/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$(dirname "$SET")"
  echo "  icon: built from icon.png"
else
  echo "  icon: skipped (no icon.png or iconutil)"
fi

# --- register so Spotlight/Launchpad/Dock pick it up ---
touch "$APP"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$APP" || true
killall Dock >/dev/null 2>&1 || true

echo
echo "Done.  Launcher: $MODE"
echo "Launch it:  Spotlight (Cmd+Space -> \"Pipes\"), Launchpad, or drag $APP to your Dock."
echo "Quit fullscreen with Cmd+Q.  Uninstall with:  rm -rf \"$APP\""
