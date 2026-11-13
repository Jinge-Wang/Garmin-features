#!/bin/zsh
# Save the watch's current picture-font table before anything is changed.
#
#   ./backup.sh
#
# Copies Garmin/ExtData/006-D8168-00.fnt from the watch to
# original/ExtData/006-D8168-00.fnt. It refuses to overwrite an existing local
# backup, and it refuses to keep a table that already holds Chinese characters
# (code points U+4E00..U+9FFF): that table is not the stock one, and saving it
# as the original would lose the real original.
#
# Needs: bin/probe_ids and bin/mtp_put (run ./setup.sh first), the watch
# plugged in by USB, and Garmin Express and OpenMTP quit.
set -u
cd "$(dirname "$0")" || exit 1
NAME="006-D8168-00.fnt"
DEST="original/ExtData/$NAME"

if pgrep -fli 'garmin express|openmtp' >/dev/null 2>&1; then
  echo "Quit Garmin Express and OpenMTP first. They hold the watch."; exit 3
fi
[ -x bin/probe_ids ] && [ -x bin/mtp_put ] || { echo "Run ./setup.sh first."; exit 2; }
[ ! -e "$DEST" ] || { echo "$DEST already exists. Not overwriting a backup."; exit 2; }
mtp-detect 2>/dev/null | grep -q 'Model: fenix 6X Pro' || {
  echo "The watch does not answer over MTP. Plug it in and close Garmin Express."; exit 3; }

last=$(mtp-files 2>/dev/null | awk '/^File ID:/{if($3>m)m=$3} END{print m}')
probe=$(mktemp "${TMPDIR:-/tmp}/cn-probe.XXXXXX") || exit 1
./bin/probe_ids 16777216 $((last + 300)) > "$probe" 2>/dev/null
ext=$(awk -F'\t' '$2=="ExtData"{print $1}' "$probe" | head -1)
id=$(awk -F'\t' -v p="$ext" -v n="$NAME" '$2==n && $4==p{print $1}' "$probe" | head -1)
rm -f "$probe"
[ -n "$ext" ] || { echo "ExtData folder not found on the watch."; exit 4; }
[ -n "$id" ] || { echo "$NAME not found in ExtData on the watch."; exit 4; }

tmp=$(mktemp "${TMPDIR:-/tmp}/cn-get.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT
./bin/mtp_put get "$id" "$tmp" | grep -vE '^(Device [0-9]|   Found|Attempting)'
[ -s "$tmp" ] || { echo "could not copy $NAME off the watch"; exit 5; }

python3 - "$tmp" <<'PY' || exit 6
import sys
sys.path.insert(0, "tools")
import fnt_build
font = fnt_build.parse(open(sys.argv[1], "rb").read())
chinese = [cp for cp in font["glyphs"] if 0x4E00 <= cp <= 0x9FFF]
if chinese:
    print("The table on the watch already holds %d code points in U+4E00..U+9FFF." % len(chinese))
    print("It is an extended table, not the stock one, so it is not saved as the original.")
    print("If you have your own copy of the stock file, place it at original/ExtData/ yourself.")
    sys.exit(1)
print("stock table: %d pictures, none in U+4E00..U+9FFF" % len(font["glyphs"]))
PY
mkdir -p original/ExtData
mv "$tmp" "$DEST"
echo "saved $DEST ($(stat -f %z "$DEST") bytes)"
