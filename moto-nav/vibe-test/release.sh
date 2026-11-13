#!/bin/sh
# Build the app for sharing: release/VibeTest.prg, without debug information.
# The file that goes into release/ holds no path of this computer.
set -eu
cd "$(dirname "$0")"
mkdir -p release
# Built in bin/ and copied: the compiler leaves side files with local paths
# next to its output, and those must not be shared.
./build.sh -r -l 2
cp bin/VibeTest.prg release/VibeTest.prg
if LC_ALL=C grep -a -q -e "$HOME" -e "/Users/" release/VibeTest.prg; then
    echo "release/VibeTest.prg holds a local path; do not share it" >&2
    exit 1
fi
ls -l release/VibeTest.prg
