#!/usr/bin/env bash
# Rebuild pixel-art textures from art/vleirand.px.js into assets/textures/pxl/.
# Needs Node >= 22.18. Previews go to art/out/_preview (git-ignored) for review.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PXL="$ROOT/.claude/skills/pxl/bin/pxl.js"
node "$PXL" build "$ROOT/art/vleirand.px.js" --out "$ROOT/art/out"
mkdir -p "$ROOT/assets/textures/pxl"
cp "$ROOT"/art/out/sprites/*.png "$ROOT/assets/textures/pxl/"
echo "Copied $(ls "$ROOT"/art/out/sprites/*.png | wc -l) textures to assets/textures/pxl/"
