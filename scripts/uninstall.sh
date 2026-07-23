#!/usr/bin/env bash
set -euo pipefail

INSTALL_BUNDLE="${HOME}/Applications/CodexUsageWidget.app"
LAUNCH_AGENT_PATH="${HOME}/Library/LaunchAgents/com.codexusagewidget.app.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PATH" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PATH"
rm -rf "$INSTALL_BUNDLE"

printf 'Removed Codex Usage Widget.\n'
