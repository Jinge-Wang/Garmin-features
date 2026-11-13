#!/bin/sh
# Copy the widget to the watch over USB, into GARMIN/APPS.
#
#   ./load.sh                     copies release/Cards.prg, or bin/Cards.prg without it
#   ./load.sh path/to/Cards.prg   copies that file
#
# The fenix 6X Pro is an MTP device, so Finder does not show it. This uses
# libmtp (brew install libmtp) and bin/mtp_put (./setup.sh builds it).
# It sends one file. A file of the same name in GARMIN/APPS is deleted first,
# after its name is checked; nothing else on the watch is touched. The new
# file is read back and compared.
#
# Before running: plug the watch in by USB, and quit Garmin Express, OpenMTP
# and Android File Transfer (their background services hold the watch).
set -eu
cd "$(dirname "$0")"

PRG="${1:-}"
if [ -z "$PRG" ]; then
    PRG=release/Cards.prg
    [ -f "$PRG" ] || PRG=bin/Cards.prg
fi
NAME="$(basename "$PRG")"
[ -f "$PRG" ] || { echo "missing $PRG: run ./build.sh or ./release.sh"; exit 2; }
[ -x bin/mtp_put ] || { echo "bin/mtp_put is missing: run ./setup.sh (needs libmtp)"; exit 2; }
if pgrep -fli 'garmin express|openmtp|android file transfer' >/dev/null 2>&1; then
    echo "Quit Garmin Express, OpenMTP and Android File Transfer first. They hold the watch."
    exit 3
fi
mtp-detect 2>/dev/null | grep -q 'Model: fenix' || {
    echo "The watch does not answer over MTP. Plug it in by USB."
    exit 3
}

# mtp-folders prints "<id><tab><two spaces per level><name>". Find APPS
# directly under GARMIN (either case).
APPS="$(mtp-folders 2>/dev/null | awk -F'\t' '
    NF >= 2 {
        name = $2; indent = 0
        while (substr(name, 1, 2) == "  ") { name = substr(name, 3); indent++ }
        up = toupper(name)
        if (up == "GARMIN") { inside = 1; level = indent; next }
        if (inside && indent <= level) { inside = 0 }
        if (inside && indent == level + 1 && up == "APPS") { print $1; exit }
    }')"
[ -n "$APPS" ] || { echo "GARMIN/APPS was not found on the watch. Nothing changed."; exit 4; }

# mtp-files prints one block per file: "File ID:", "Filename:", "Parent ID:".
OLD="$(mtp-files 2>/dev/null | awk -v want="$NAME" -v parent="$APPS" '
    /^File ID:/ { id = $3 }
    /Filename:/ { sub(/^[ \t]*Filename:[ \t]*/, ""); name = $0 }
    /Parent ID:/ { if (toupper(name) == toupper(want) && $3 == parent) { print id "\t" name; exit } }')"
if [ -n "$OLD" ]; then
    OLD_ID="${OLD%%	*}"
    OLD_NAME="${OLD#*	}"
    echo "replacing $OLD_NAME (object $OLD_ID)"
    bin/mtp_put delete "$OLD_ID" "$OLD_NAME"
fi
bin/mtp_put send "$APPS" "$NAME" "$PRG"
echo "Unplug the watch. The widget is in the widget list as CARDS; add it to the list from the watch's widget settings if it is not shown."
