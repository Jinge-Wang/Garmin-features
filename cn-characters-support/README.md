# Chinese reading support for the Garmin fenix 6X Pro

The worldwide edition of the fenix 6X Pro has no Chinese font, so Chinese text
in phone notifications shows as diamonds. This project adds a picture of every
Chinese character to the watch's emoji picture-font table. The watch then draws
Chinese in notifications and messages. It replaces one file on the watch and
changes no firmware.

This project is not affiliated with Garmin. It includes no Garmin files: the
watch's own table is read from your watch (step 2), and the Chinese pictures in
`pack/` are added to it on your Mac.

## What it does and does not do

- Chinese text in incoming notifications and messages is drawn.
- Menus and system text are not translated. They stay in the language the
  watch is set to.
- Chinese text is one fixed color (blue), because the characters are pictures,
  not a font. The watch has light and dark backgrounds, and the color was chosen
  to stay readable on both.
- Tested on one model and firmware only: fenix 6X Pro, worldwide edition,
  firmware 28.02. Other models and firmware versions are untested.
- Covers U+4E00..U+9FEF (20,976 characters, simplified and traditional) plus
  Chinese punctuation and the wide space. Characters outside that range are not
  added.

## Warning

`load.sh` replaces the file `Garmin/ExtData/006-D8168-00.fnt` on the watch. A
wrong or damaged file there can change how the watch draws text. `backup.sh`
saves the one file this project changes; copying the watch's other files is up
to you. Use it at your own risk. A firmware update can reset the table; run
`load.sh` again afterward.

## Status

- `setup.sh` and `build.sh` were run on macOS (Apple silicon). The table built
  from a saved original plus `pack/chinese.pack.gz` is byte for byte the table
  that was loaded on the watch and used.
- The watch operations the scripts are made of (find the table, delete it, send
  a file, read it back) were used many times on one watch during development.
  `backup.sh` and `load.sh` in their current form have not yet been run end to
  end.

## Requirements

- macOS with Homebrew and `python3`
- libmtp: `brew install libmtp`
- Xcode command line tools (a C compiler): `xcode-select --install`
- The watch connected by USB, with Garmin Express and OpenMTP quit (their
  background services hold the watch)

## Steps

1. Build the tools: `./setup.sh`
2. Save the watch's current table: `./backup.sh`
   This copies the watch's table to `original/ExtData/006-D8168-00.fnt`. It
   refuses to overwrite an existing backup. It also refuses to keep a table that
   already holds Chinese characters, because that is not the stock table.
3. Load the extended table: `./load.sh`
   The first run builds `final/006-D8168-00.fnt` (about 14 MB) from your saved
   table and `pack/chinese.pack.gz`, which takes a few seconds. It then deletes
   the current table on the watch, sends the new one, and reads it back to
   confirm the copy. It refuses to run without the saved original from step 2,
   and sends that original back if the transfer fails.

To undo: `./revert.sh` sends the saved original back to the watch.

The scripts that talk to the watch (`backup.sh`, `load.sh`, `revert.sh`) use
`mtp-detect` and `mtp-files` from libmtp, and the programs in `bin/`. They
refuse to run while Garmin Express or OpenMTP is running or when the watch does
not answer.

## The picture pack

`pack/chinese.pack.gz` (1.2 MB) holds the 21,133 added pictures and nothing
else: each is 23 x 27 pixels, drawn from Noto Sans SC at weight 600 and 25 px.
The format is described at the top of `tools/fnt_build.py`.

To draw the pictures again from another font, weight or color, run
`./build.sh`. It needs `swiftc` (Xcode command line tools) and a font file; the
default is Noto Sans SC (`brew install --cask font-noto-sans-sc`). Options:
`--font <file>`, `--weight <wght>`, `--ink <hex>`, or the environment variables
`FONT`, `WEIGHT`, `INK`. The ink is a palette value (6-bit RRGGBB); the default
`0x17` is blue. `build.sh` rewrites both `final/006-D8168-00.fnt` and the pack.
A pack drawn from another font carries that font's license, not the one below.

## How it works

The file `006-D8168-00.fnt` holds the watch's emoji pictures. The watch draws
any code point the table lists, emoji or not, so Chinese characters can be added
as pictures. All integers are little-endian.

- A 36-byte header, then a range table (first code point, last code point, index
  of the first picture), then one 32-bit entry per picture (low 24 bits: offset
  into the picture data; high 8 bits: picture width), then the pictures, then a
  21-byte trailer.
- Each picture is height 27 and one byte per pixel. A byte is one of 64 colors
  (6-bit RRGGBB) or 0xFF for transparent.
- Width is free from 1 to 255 pixels, and the watch advances by the picture's
  width. Each Chinese character is 23 pixels wide.

The pipeline behind the pack:

1. `tools/render_glyphs.swift` draws the characters from the font with CoreText
   into a 35 x 27 cell at 25 px.
2. `tools/crop_glyphs.py` cuts columns 6..28 and slides a glyph sideways when its
   ink would otherwise be cut off.
3. `tools/fnt_build.py` turns coverage into the ink color, adds the pictures to
   a table, and recomputes the ranges, offsets and sizes. Its `--selftest`
   rebuilds a table with nothing added and checks that the result is
   byte-for-byte identical, which shows the format is fully understood.

## Measured limits

Measured on a fenix 6X Pro, firmware 28.02.

| Item | Result |
| --- | --- |
| Space between pictures | The watch adds 2 px |
| Advance | Picture width |
| Table size | A 14.2 MB table is accepted (the stock one is 1 MB); the format's 24-bit offsets cap the picture data at 16.7 MB |
| Four check bytes after the body | Not checked; a rebuilt file is accepted |

## What does not work

The watch loads fonts for Hebrew and Arabic from font files, but it routes
characters to those files by a script list held in the firmware, not in any file
on the watch. Chinese placed in a font file under any other name is ignored.
Real scalable Chinese text would require changing the firmware, which this
project does not do. Pictures are therefore the method, and the cost is the
fixed color.

## Licenses

- The scripts, programs and documentation are under the MIT License (see
  `LICENSE` at the repository root).
- `pack/chinese.pack.gz` is a rendering of Noto Sans SC in another format, which
  makes it a modified version of that font. It is distributed under the SIL
  Open Font License, Version 1.1; the font's copyright notice and the license
  are in `pack/OFL.txt`. It does not use the font's reserved name.

## Layout

    setup.sh, backup.sh, load.sh    the three steps
    revert.sh                       undo
    build.sh                        optional: draw the pictures again from a font
    pack/                           the Chinese pictures and their license
    tools/                          the build pipeline and the MTP programs' sources
    research/                       scripts used to work out the formats (not needed)
    original/, final/, bin/         created locally and not published
