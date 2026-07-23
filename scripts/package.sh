#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
ARCHIVE="$DIST_DIR/CodexUsageWidget-0.1.1-macos.zip"

"$PROJECT_ROOT/scripts/build.sh"
mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
ditto -c -k --norsrc --keepParent "$PROJECT_ROOT/build/CodexUsageWidget.app" "$ARCHIVE"

printf 'Packaged %s\n' "$ARCHIVE"
