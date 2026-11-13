#!/bin/sh
# Rebuild the fixtures the phone app's tests compare against:
#   qr-*.png       dummy QR pictures (drawn by fixture_pictures.swift)
#   list.json      the card list given to the Mac tool
#   expected.json  what tools/cardtool.swift writes for that list
# The phone's record for each picture and each number must equal the entry in
# expected.json. Every code is a dummy. Needs macOS with swiftc; the Gradle
# tests only read the files, so they run without it.
set -eu
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# SWIFTC_FLAGS: extra compiler flags, for example a module cache folder
swiftc -O ${SWIFTC_FLAGS:-} -o "$WORK/fixture_pictures" fixture_pictures.swift
swiftc -O ${SWIFTC_FLAGS:-} -o "$WORK/cardtool" ../../tools/cardtool.swift

rm -f qr-*.png list.json expected.json
"$WORK/fixture_pictures" . "$WORK/source-grids.json"
"$WORK/cardtool" list.json expected.json "$WORK/previews" 280
"$WORK/fixture_pictures" check expected.json "$WORK/source-grids.json"
