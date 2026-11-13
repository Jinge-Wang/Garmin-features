#!/bin/bash
# simtest.sh <tests.prg>: runs a unit-test build in the Connect IQ simulator
# (which must already be open) and prints the result table.
[ -n "$1" ] || { echo "usage: simtest.sh <tests.prg>"; exit 2; }
if ! java -version >/dev/null 2>&1; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
fi
sdk="$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")"
pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null || { echo "the simulator is not running: open <SDK>/bin/ConnectIQ.app"; exit 1; }
log="$(mktemp "${TMPDIR:-/tmp}/ciq-test.XXXXXX")"
pkill -f monkeydodeux 2>/dev/null
"${sdk%/}/bin/monkeydo" "$1" fenix6xpro -t > "$log" 2>&1 &
mpid=$!
for i in $(seq 1 90); do
    grep -q -E '^(PASSED|FAILED) \(passed' "$log" 2>/dev/null && break
    perl -e 'select(undef,undef,undef,1)'
done
kill "$mpid" 2>/dev/null; pkill -f monkeydodeux 2>/dev/null
sed -n '/^RESULTS/,$p' "$log"
grep -q '^PASSED (passed' "$log"; ok=$?
rm -f "$log"
exit $ok
