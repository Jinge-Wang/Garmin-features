#!/bin/sh
# Build the widget for sharing: release/Cards.prg, with no built-in cards and
# no debug information. Cards are then added on the watch or from the phone.
# The file that goes into release/ holds no card and no path of this computer.
set -eu
cd "$(dirname "$0")"
mkdir -p release
# Built in bin/ and copied: the compiler leaves side files with local paths
# next to its output, and those must not be shared.
CARDS_LIST=cards.empty.json OUT=bin/Cards-release.prg ./build.sh -r -l 2
cp bin/Cards-release.prg release/Cards.prg
if LC_ALL=C grep -a -q -e "$HOME" -e "/Users/" release/Cards.prg; then
    echo "release/Cards.prg holds a local path; do not share it" >&2
    exit 1
fi
ls -l release/Cards.prg
