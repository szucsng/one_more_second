#!/usr/bin/env bash
# Build the production web export and an itch.io-ready ZIP.
# Requires Godot 4.7.2 with Web export templates installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
  echo "Godot not found. Set GODOT_BIN to the Godot 4.7.2 executable." >&2
  exit 1
fi

rm -rf exports/web
mkdir -p exports/web

"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$ROOT/exports/web/index.html"

touch exports/web/.nojekyll
rm -f exports/one-more-second-web.zip
(cd exports/web && zip -q -r ../one-more-second-web.zip .)

echo "Web build: exports/web"
echo "itch.io package: exports/one-more-second-web.zip"
du -sh exports/web exports/one-more-second-web.zip
echo
echo "Local preview:"
echo "  python3 -m http.server 8080 --directory exports/web"
echo "  open http://localhost:8080"
