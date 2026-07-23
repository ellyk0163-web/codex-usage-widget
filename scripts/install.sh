#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/CodexUsageWidget.app"
USER_APPLICATIONS_DIR="${HOME}/Applications"
INSTALL_BUNDLE="$USER_APPLICATIONS_DIR/CodexUsageWidget.app"
LAUNCH_AGENT_DIR="${HOME}/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENT_DIR/com.codexusagewidget.app.plist"

if [[ ! -d "$APP_BUNDLE" ]]; then
  "$PROJECT_ROOT/scripts/build.sh"
fi

mkdir -p "$USER_APPLICATIONS_DIR" "$LAUNCH_AGENT_DIR"
rm -rf "$INSTALL_BUNDLE"
ditto "$APP_BUNDLE" "$INSTALL_BUNDLE"

cat > "$LAUNCH_AGENT_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.codexusagewidget.app</string>
  <key>ProgramArguments</key>
  <array>
    <string>__APP_EXECUTABLE__</string>
  </array>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST

sed -i '' "s|__APP_EXECUTABLE__|$INSTALL_BUNDLE/Contents/MacOS/CodexUsageWidget|" "$LAUNCH_AGENT_PATH"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PATH" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PATH"

printf 'Installed %s and enabled launch at login.\n' "$INSTALL_BUNDLE"
