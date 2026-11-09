#!/usr/bin/env bash
# Builds the Windows release: build/windows/Gangstars.exe (game data embedded) and a zip.
# Needs the Godot 4.5.1 export templates. The script installs just the Windows ones when they
# are missing, fetching only those files out of the official 1.3 GB template archive.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TPL="${HOME}/.local/share/godot/export_templates/4.5.1.stable"
URL="https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz"
if [ ! -f "$TPL/windows_release_x86_64.exe" ]; then
  mkdir -p "$TPL"
  python3 -I tools/remote_zip.py "$URL" "$TPL" windows_release_x86_64.exe windows_debug_x86_64.exe
fi
mkdir -p build/windows
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/Gangstars.exe
(cd build/windows && rm -f Gangstars-windows.zip && zip -q -9 Gangstars-windows.zip Gangstars.exe)
ls -la build/windows
