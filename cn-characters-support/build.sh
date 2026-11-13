#!/bin/zsh
# Build final/006-D8168-00.fnt: the stock picture-font table plus one picture
# per Chinese character.
#
#   ./build.sh [--font <font file>] [--weight <wght>] [--ink <hex colour>]
#
# Environment variables FONT, WEIGHT and INK do the same as the options.
# Defaults: FONT=~/Library/Fonts/NotoSansSC[wght].ttf (brew install --cask
# font-noto-sans-sc), WEIGHT=600, INK=0x17 (blue, a 6-bit RRGGBB palette value).
# The glyph size is 25 px and the crop window is columns 6..28 of a 35 x 27 cell.
#
# Input:  original/ExtData/006-D8168-00.fnt (see backup.sh)
# Output: final/006-D8168-00.fnt
# Needs:  bin/render_glyphs (see setup.sh) and python3.
set -u
cd "$(dirname "$0")" || exit 1

FONT="${FONT:-$HOME/Library/Fonts/NotoSansSC[wght].ttf}"
WEIGHT="${WEIGHT:-600}"
INK="${INK:-0x17}"
while [ $# -gt 0 ]; do
  case "$1" in
    --font)   FONT="${2:?--font needs a value}"; shift 2 ;;
    --weight) WEIGHT="${2:?--weight needs a value}"; shift 2 ;;
    --ink)    INK="${2:?--ink needs a value}"; shift 2 ;;
    *) echo "usage: ./build.sh [--font <file>] [--weight <wght>] [--ink <hex>]"; exit 2 ;;
  esac
done

SRC="original/ExtData/006-D8168-00.fnt"
OUT="final/006-D8168-00.fnt"
[ -f "$SRC" ] || { echo "missing $SRC. Run ./backup.sh first."; exit 2; }
[ -f "$FONT" ] || { echo "font not found: $FONT"; echo "Install one with:  brew install --cask font-noto-sans-sc"; exit 2; }
[ -x bin/render_glyphs ] || { echo "Run ./setup.sh first."; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/cn-build.XXXXXX") || { echo "cannot create a temporary directory"; exit 1; }
trap 'rm -rf "$work"' EXIT
SPEC="$FONT@$WEIGHT"
STYLE="mono:$INK:110"

# Characters to draw: the Chinese block, and the punctuation the stock table lacks.
python3 - "$SRC" "$work" <<'PY' || exit 1
import sys
sys.path.insert(0, "tools")
import fnt_build
have = set(fnt_build.parse(open(sys.argv[1], "rb").read())["glyphs"])
work = sys.argv[2]
block = "".join(chr(c) for c in range(0x4E00, 0x9FF0))
cands = list(range(0x3001, 0x3040)) + list(range(0xFF01, 0xFF5F)) + [0xFFE5]
punct = "".join(chr(c) for c in cands if c not in have)
open(work + "/block.txt", "w", encoding="utf-8").write(block)
open(work + "/punct.txt", "w", encoding="utf-8").write(punct)
PY

echo "== Chinese block"
./bin/render_glyphs "$SPEC" 35 27 25 "$(cat "$work/block.txt")" "$work/block.wide" || exit 1
python3 tools/crop_glyphs.py "$work/block.wide" "$work/block.glyphs" 6 28 --fit || exit 1
echo "== punctuation"
./bin/render_glyphs "$SPEC" 35 27 25 "$(cat "$work/punct.txt")" "$work/punct.wide" --skip-missing || exit 1
python3 tools/crop_glyphs.py "$work/punct.wide" "$work/punct.glyphs" 6 28 --fit || exit 1
echo "== wide space"
python3 -c 'print("3000 23 27 " + "00" * (23 * 27))' > "$work/space.glyphs"

echo "== assemble"
mkdir -p final
python3 tools/fnt_build.py "$SRC" "$work/out.fnt" \
  --add "$work/block.glyphs" "$STYLE" \
  --add "$work/punct.glyphs" "$STYLE" \
  --add "$work/space.glyphs" "$STYLE" \
  --write-pack "$work/chinese.pack.gz" || { echo "assembly failed; $OUT not changed"; exit 1; }
mv "$work/out.fnt" "$OUT"
mkdir -p pack
mv "$work/chinese.pack.gz" pack/chinese.pack.gz
echo "wrote pack/chinese.pack.gz ($(stat -f %z pack/chinese.pack.gz) bytes): the added pictures alone"

echo "== self-test on the original"
python3 tools/fnt_build.py --selftest "$SRC" || exit 1
echo "built $OUT ($(stat -f %z "$OUT") bytes)"
