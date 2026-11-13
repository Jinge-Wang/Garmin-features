#!/bin/sh
# Turn the card list into the data the watch app is built with
# (resources/data/cards.json: a stamp and the cards; the watch imports it once).
# Reads cards.local.json (your cards; never committed) or, without it, the
# sample list. Runs on this computer only and prints no card content.
set -eu
cd "$(dirname "$0")"

SRC=tools/cardtool.swift
BIN=bin/cardtool
mkdir -p bin private resources/data

if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
    # SWIFTC_FLAGS: extra compiler flags, for example a module cache folder
    swiftc -O ${SWIFTC_FLAGS:-} -o "$BIN" "$SRC"
fi

# CARDS_LIST names another list (release.sh uses the empty one).
LIST="${CARDS_LIST:-cards.local.json}"
[ -f "$LIST" ] || LIST=cards.example.json
echo "cards from $LIST"
"$BIN" "$LIST" resources/data/cards.json private "${SCREEN_PX:-280}"
