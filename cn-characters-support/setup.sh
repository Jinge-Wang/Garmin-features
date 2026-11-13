#!/bin/zsh
# Build the helper programs this project needs.
#
#   bin/probe_ids      lists objects on the watch by id (read only)
#   bin/mtp_put        copies one object off the watch, sends or deletes a file
#   bin/render_glyphs  draws characters from a font file (optional; only build.sh uses it)
#
# Needs: macOS, Homebrew, libmtp (brew install libmtp), and the Xcode command
# line tools (cc and swiftc; xcode-select --install).
set -u
cd "$(dirname "$0")" || exit 1

command -v brew >/dev/null 2>&1 || { echo "Homebrew is not installed (https://brew.sh)."; exit 1; }
PREFIX=$(brew --prefix)
if [ ! -f "$PREFIX/include/libmtp.h" ]; then
  echo "libmtp is not installed. Install it with:  brew install libmtp"; exit 1
fi
command -v cc >/dev/null 2>&1 || { echo "No C compiler. Install the Xcode command line tools:  xcode-select --install"; exit 1; }

mkdir -p bin
for name in probe_ids mtp_put; do
  echo "building bin/$name"
  cc -O1 -Wall -I"$PREFIX/include" -L"$PREFIX/lib" -o "bin/$name" "tools/$name.c" -lmtp || {
    echo "build of $name failed"; exit 1; }
done
# render_glyphs is only needed to redraw the pictures from a font (build.sh).
if command -v swiftc >/dev/null 2>&1; then
  echo "building bin/render_glyphs"
  swiftc -O -o bin/render_glyphs tools/render_glyphs.swift || echo "build of render_glyphs failed (only build.sh needs it)"
else
  echo "no swiftc: skipping bin/render_glyphs (only build.sh needs it)"
fi
echo "done: $(ls bin | tr '\n' ' ')"
