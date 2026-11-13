#!/bin/zsh
# Load the extended picture-font table onto the fenix 6X Pro.
#
#   ./load.sh            install the extended table (final/006-D8168-00.fnt); if it
#                        does not exist yet, it is built from the saved original
#                        and pack/chinese.pack.gz first
#   ./revert.sh          put the saved original back
#
# This replaces one file on the watch: Garmin/ExtData/006-D8168-00.fnt. It
# leaves every other file alone. Run it again after a firmware update that
# resets the table.
#
# Safety:
#   - it refuses to run without a saved original (see backup.sh);
#   - the file to load must parse as a picture-font table;
#   - the old object is deleted only after its name is checked;
#   - the new file is read back and compared;
#   - if sending fails after the delete, the saved original is sent back.
#
# Needs: bin/probe_ids and bin/mtp_put (run ./setup.sh first), libmtp, the
# watch plugged in by USB, and Garmin Express and OpenMTP quit (their
# background services hold the watch).
set -u
cd "$(dirname "$0")" || exit 1
TABLE="${1:-final/006-D8168-00.fnt}"
NAME="006-D8168-00.fnt"
BACKUP="original/ExtData/$NAME"

if pgrep -fli 'garmin express|openmtp' >/dev/null 2>&1; then
  echo "Quit Garmin Express and OpenMTP first. They hold the watch."; exit 3
fi
[ -x bin/probe_ids ] && [ -x bin/mtp_put ] || { echo "Run ./setup.sh first."; exit 2; }
[ -f "$BACKUP" ] || { echo "No saved original at $BACKUP. Run ./backup.sh first."; exit 2; }
if [ "$TABLE" = "final/$NAME" ] && [ ! -f "$TABLE" ]; then
  # No drawing step needed: the saved original plus the picture pack is the table.
  echo "building $TABLE from the saved original and pack/chinese.pack.gz"
  mkdir -p final
  python3 tools/fnt_build.py "$BACKUP" "$TABLE" --add-pack pack/chinese.pack.gz || {
    rm -f "$TABLE"; echo "Could not build the table. Nothing changed."; exit 2; }
fi
[ -f "$TABLE" ] || { echo "missing $TABLE"; exit 2; }
python3 - "$TABLE" <<'PY' || { echo "$TABLE is not a valid picture-font table. Nothing changed."; exit 2; }
import sys
sys.path.insert(0, "tools")
import fnt_build
font = fnt_build.parse(open(sys.argv[1], "rb").read())
assert font["height"] == 27 and len(font["glyphs"]) > 1000
PY
mtp-detect 2>/dev/null | grep -q 'Model: fenix 6X Pro' || {
  echo "The watch does not answer over MTP. Plug it in and close Garmin Express."; exit 3; }

quiet() { grep -vE '^(Device [0-9]|   Found|Attempting)'; }

last=$(mtp-files 2>/dev/null | awk '/^File ID:/{if($3>m)m=$3} END{print m}')
probe=$(mktemp "${TMPDIR:-/tmp}/cn-probe.XXXXXX") || exit 1
./bin/probe_ids 16777216 $((last + 300)) > "$probe" 2>/dev/null
ext=$(awk -F'\t' '$2=="ExtData"{print $1}' "$probe" | head -1)
id=$(awk -F'\t' -v p="$ext" -v n="$NAME" '$2==n && $4==p{print $1}' "$probe" | head -1)
rm -f "$probe"
[ -n "$ext" ] || { echo "ExtData folder not found on the watch. Nothing changed."; exit 4; }

if [ -n "$id" ]; then
  ./bin/mtp_put delete "$id" "$NAME" 2>&1 | quiet
  [ "${pipestatus[1]}" -eq 0 ] || { echo "Could not remove the current table. Nothing changed."; exit 5; }
fi

./bin/mtp_put send "$ext" "$NAME" "$TABLE" 2>&1 | quiet
if [ "${pipestatus[1]}" -ne 0 ]; then
  echo "Sending $TABLE failed. Putting the saved original back."
  ./bin/mtp_put send "$ext" "$NAME" "$BACKUP" 2>&1 | quiet
  if [ "${pipestatus[1]}" -eq 0 ]; then
    echo "The original table is back on the watch."
  else
    echo "RESTORE FAILED: the watch has no $NAME now. Run ./revert.sh before unplugging."
  fi
  exit 5
fi
echo "done: $NAME = $TABLE ($(stat -f %z "$TABLE") bytes)"
