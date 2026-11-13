#!/bin/zsh
# Put a new emoji-table file and/or a new Danish language file on the watch.
#
# usage: research/push_test.sh <new .fnt or -> <new danish.ln4 or ->
#   (run from the project folder; bin/replace_file is built from research/replace_file.c)
#
# What it does, for each of the two files given:
#   1. refuses to run while a Garmin Express or OpenMTP process exists;
#   2. looks up the file's current object id on the watch (ids change at every
#      plug-in; the font folder is hidden, so its entries are found by asking
#      for each id in turn);
#   3. replaces it with bin/replace_file, which first checks that the watch
#      holds exactly the file named in state/<slot>.current, and reads the new
#      file back after sending;
#   4. records the new file in state/<slot>.current.
#
# Only these two files are ever touched:
#   Garmin/ExtData/006-D8168-00.fnt   and   GARMIN/Text/danish.ln4
set -u
cd "$(dirname "$0")/.." || exit 1
NEW_FNT="${1:--}"
NEW_LN4="${2:--}"
mkdir -p state logs

if pgrep -fl -i 'garmin express|openmtp' >/dev/null 2>&1; then
  echo "A Garmin Express or OpenMTP process is running; it holds the watch. Stop."
  pgrep -fl -i 'garmin express|openmtp' | awk '{print "  ", $1, $NF}'
  exit 3
fi
if ! mtp-detect 2>/dev/null | grep -q 'Model: fenix 6X Pro'; then
  echo "The watch does not answer over MTP (unplugged, or in Garmin mode). Stop."
  exit 3
fi

quiet() { grep -vE '^(Device [0-9]|   Found|Attempting)'; }

if [ "$NEW_LN4" != "-" ]; then
  cur=$(cat state/danish.current)
  text_id=$(mtp-folders 2>/dev/null | awk '$2=="Text"{print $1}' | head -1)
  id=$(mtp-files 2>/dev/null | awk -v p="$text_id" '/^File ID:/{id=$3} /^   Filename:/{sub(/^   Filename: /,""); fn=$0} /^   Parent ID:/{if(fn=="danish.ln4" && $3==p) print id}' | head -1)
  echo "== danish.ln4: object $id in Text ($text_id); on the watch now: $cur"
  [ -n "$id" ] || { echo "danish.ln4 not found. Stop."; exit 4; }
  ./bin/replace_file "$id" danish.ln4 "$cur" "$NEW_LN4" 2>&1 | quiet
  if [ "${pipestatus[1]}" -ne 0 ]; then echo "danish.ln4 NOT replaced"; exit 5; fi
  echo "$NEW_LN4" > state/danish.current
  rm -f "$NEW_LN4".on-watch-before "$NEW_LN4".on-watch-after
fi

if [ "$NEW_FNT" != "-" ]; then
  cur=$(cat state/fnt.current)
  last=$(mtp-files 2>/dev/null | awk '/^File ID:/{if($3>m)m=$3} END{print m}')
  ./bin/probe_ids 16777216 $((last + 300)) > logs/probe_last.tsv 2>/dev/null
  ext_id=$(awk -F'\t' '$2=="ExtData"{print $1}' logs/probe_last.tsv | head -1)
  id=$(awk -F'\t' -v p="$ext_id" '$2=="006-D8168-00.fnt" && $4==p{print $1}' logs/probe_last.tsv | head -1)
  echo "== 006-D8168-00.fnt: object $id in ExtData ($ext_id); on the watch now: $cur"
  [ -n "$id" ] || { echo "006-D8168-00.fnt not found. Stop."; exit 4; }
  ./bin/replace_file "$id" 006-D8168-00.fnt "$cur" "$NEW_FNT" 2>&1 | quiet
  if [ "${pipestatus[1]}" -ne 0 ]; then echo "006-D8168-00.fnt NOT replaced"; exit 5; fi
  echo "$NEW_FNT" > state/fnt.current
  rm -f "$NEW_FNT".on-watch-before "$NEW_FNT".on-watch-after
fi

echo "== on the watch now"
echo "   emoji table : $(cat state/fnt.current) ($(stat -f %z "$(cat state/fnt.current)") bytes)"
echo "   Danish slot : $(cat state/danish.current) ($(stat -f %z "$(cat state/danish.current)") bytes)"
