#!/bin/bash
# simrun.sh <app.prg> <output folder> [seconds]
# Runs an app in the Connect IQ simulator (which must already be open) and
# saves a picture of the simulator's own window after every line the app
# prints that starts with "step ". Used with the check build (check.jungle),
# whose timer presses the buttons. Captures only that one window, never the
# screen; the program that runs this needs the Screen Recording permission.
here="$(cd "$(dirname "$0")" && pwd)"
prg="$1"; out="$2"; limit="${3:-150}"
[ -n "$prg" ] && [ -n "$out" ] || { echo "usage: simrun.sh <app.prg> <output folder> [seconds]"; exit 2; }
if ! java -version >/dev/null 2>&1; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
fi
sdk="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
pid=$(pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" | head -1)
[ -n "$pid" ] || { echo "the simulator is not running: open <SDK>/bin/ConnectIQ.app"; exit 1; }
bin="${TMPDIR:-/tmp}/ciq-sim-tools"; mkdir -p "$bin"
[ -x "$bin/winlist" ] || swiftc -O -o "$bin/winlist" "$here/winlist.swift" || exit 1
pkill -f monkeydodeux 2>/dev/null
mkdir -p "$out"; rm -f "$out"/*.png "$out/run.log"
log="$out/run.log"
"${sdk%/}/bin/monkeydo" "$prg" fenix6xpro > "$log" 2>&1 &
mpid=$!
nap() { perl -e "select(undef,undef,undef,$1)"; }
seen=0
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt "$limit" ]; do
    count=$(grep -c '^step ' "$log" 2>/dev/null); count=${count:-0}
    if [ "$count" -gt "$seen" ]; then
        seen=$count
        nap 1.2
        win=$("$bin/winlist" "$pid" | sed -n 's/^num=\([0-9]*\) layer=0 .*/\1/p' | head -1)
        [ -n "$win" ] && screencapture -x -o -l "$win" "$out/$(printf '%02d' $((seen - 1))).png"
        if grep -q '^step .* done' "$log"; then break; fi
    fi
    if grep -q -E 'Error:|Exception|Unhandled' "$log"; then nap 1.5; break; fi
    nap 0.3
done
kill "$mpid" 2>/dev/null; pkill -f monkeydodeux 2>/dev/null
cat "$log"
echo "pictures: $(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ') in $out"
