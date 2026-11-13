#!/bin/zsh
# Put one file into the watch's hidden font folder (Garmin/ExtData), with checks.
#
# usage: research/push_extdata.sh <name on the watch> <new local file>
#        research/push_extdata.sh <name on the watch> --remove
#   (run from the project folder; bin/replace_file is built from research/replace_file.c)
#
# - If the watch already holds a file of that name, it is replaced with
#   bin/replace_file, which first checks that the watch holds exactly the file
#   recorded in state/<name>.current and reads the new file back after sending.
# - If the watch has no file of that name, the new file is sent and read back.
# - --remove deletes a file that this project added (it must be recorded in
#   state/, so the watch's own files cannot be removed by mistake).
#
# Investigation aid. Use it only on a watch whose files you have backed up.
set -u
cd "$(dirname "$0")/.." || exit 1
NAME="$1"
NEW="$2"
mkdir -p state logs

if pgrep -fl -i 'garmin express|openmtp' >/dev/null 2>&1; then
  echo "A Garmin Express or OpenMTP process is running; it holds the watch. Stop."
  exit 3
fi
if ! mtp-detect 2>/dev/null | grep -q 'Model: fenix 6X Pro'; then
  echo "The watch does not answer over MTP (unplugged, or in Garmin mode). Stop."
  exit 3
fi
quiet() { grep -vE '^(Device [0-9]|   Found|Attempting)'; }

last=$(mtp-files 2>/dev/null | awk '/^File ID:/{if($3>m)m=$3} END{print m}')
./bin/probe_ids 16777216 $((last + 300)) > logs/probe_last.tsv 2>/dev/null
ext_id=$(awk -F'\t' '$2=="ExtData"{print $1}' logs/probe_last.tsv | head -1)
[ -n "$ext_id" ] || { echo "ExtData folder not found. Stop."; exit 4; }
id=$(awk -F'\t' -v p="$ext_id" -v n="$NAME" '$2==n && $4==p{print $1}' logs/probe_last.tsv | head -1)
state="state/$NAME.current"

if [ "$NEW" = "--remove" ]; then
  [ -f "$state" ] || { echo "$NAME is not recorded as added by this project. Stop."; exit 6; }
  [ -n "$id" ] || { echo "$NAME is not on the watch."; rm -f "$state"; exit 0; }
  ./bin/mtp_put delete "$id" "$NAME" 2>&1 | quiet
  [ "${pipestatus[1]}" -eq 0 ] && rm -f "$state" && echo "== $NAME removed from the watch"
  exit 0
fi

[ -f "$NEW" ] || { echo "local file $NEW missing. Stop."; exit 2; }
if [ -n "$id" ]; then
  [ -f "$state" ] || { echo "$NAME is on the watch but state/$NAME.current is missing. Stop."; exit 6; }
  cur=$(cat "$state")
  echo "== $NAME: object $id in ExtData ($ext_id); on the watch now: $cur"
  ./bin/replace_file "$id" "$NAME" "$cur" "$NEW" 2>&1 | quiet
  if [ "${pipestatus[1]}" -ne 0 ]; then echo "$NAME NOT replaced"; exit 5; fi
  rm -f "$NEW".on-watch-before "$NEW".on-watch-after
else
  echo "== $NAME: not on the watch; sending it into ExtData ($ext_id)"
  ./bin/mtp_put send "$ext_id" "$NAME" "$NEW" 2>&1 | quiet
  if [ "${pipestatus[1]}" -ne 0 ]; then echo "$NAME NOT sent"; exit 5; fi
fi
echo "$NEW" > "$state"
echo "== on the watch now: $NAME = $NEW ($(stat -f %z "$NEW") bytes)"
