#!/usr/bin/env bash
# Regenerate the small WOFF2 used by the custom web shell and ad prompt.
# Requires Python fonttools + brotli: pip install fonttools brotli
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p web/fonts
python3 -m fontTools.subset assets/fonts/Rajdhani-Bold.ttf \
  --output-file=web/fonts/rajdhani-bold.woff2 \
  --flavor=woff2 \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2000-206F,U+20AC" \
  --layout-features="*" \
  --name-IDs="*" \
  --glyph-names \
  --symbol-cmap \
  --legacy-cmap \
  --notdef-glyph \
  --notdef-outline \
  --recommended-glyphs
echo "wrote web/fonts/rajdhani-bold.woff2"
