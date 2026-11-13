# Cards: membership codes on the watch

A Connect IQ widget that keeps the bar codes and QR codes of membership cards
on the watch and shows one full screen, so the card can stay at home. It sits
in the widget list next to weather and music controls. Codes can be renamed
and deleted on the watch, a bar code can be added by typing its number, and a
card can be sent from an Android phone (`android/`). If a code stops working,
delete it or replace it. The widget makes no web request.

## How the code stays off the internet

| Step | Where it runs | What leaves the computer |
| --- | --- | --- |
| Read the code from a picture | `tools/cardtool.swift`, with macOS Vision | nothing |
| Redraw the same code as a grid | the same tool, with Core Image | nothing |
| Build the widget | Connect IQ compiler, local | nothing |
| Copy the widget to the watch | USB | nothing |
| Show the code | the watch | nothing: the widget's one permission is the phone link, and its code makes no web request |

The widget asks for one Connect IQ permission, Communications, so that it can
receive a card from the phone app. That permission also covers web requests, so
the runtime no longer rules them out; the source does. `build.sh` stops when a
file in `source/` calls a web-request function. The phone route has its own
table in `android/README.md`: there the card passes through the Garmin Connect
app on the phone.

The tool prints sizes and check results, never the content of a code. Your
pictures, the card list, the generated data, the built widget and the signing
key are all listed in `.gitignore` (`private/`, `cards.local.json`,
`resources/data/cards.json`, `bin/`).

If you work with an AI assistant, do not let it open the files in `private/`,
`resources/data/cards.json` or the built `.prg`: whatever it reads is sent to
its provider.

## Use

1. For a QR code, get a picture of it onto the computer without a cloud
   service: a screenshot copied over a USB cable, or a photo. Put it in
   `private/`. For a bar code you only need its number.
2. Write `cards.local.json` (copy `cards.example.json`):

   ```json
   { "cards": [
     { "name": "Warehouse", "image": "private/warehouse.png" },
     { "name": "Library", "number": "0000 1234 5678" }
   ] }
   ```

   `name` is the label on the watch. A QR code comes from `"image"`, or from
   `"text": "..."` when you know its content and want to type it. A bar code
   (Code 128) comes from `"number"`: ASCII 33 to 126, any length that fits the
   screen. Spaces are dropped, since they are how a number is printed and not
   part of the code. Names must differ.
3. `./setup.sh` once, to make the signing key.
4. `./build.sh` makes `bin/Cards.prg`. It prints one line per card, for example

   ```
   Warehouse: QR version 3 (29 x 29 modules), error correction M, 40 characters, 6 px per module on a 280 px screen
     exact copy of the picture's code: yes; reads back: yes; reads at watch size: yes
   Library: bar code (Code 128), 14 characters; the watch draws it
   ```

   and writes `private/preview-<name>.png`, a picture of the watch screen for
   each QR code.
5. Copy `bin/Cards.prg` to the watch's `GARMIN/APPS` folder over USB.

On the watch: scroll the widget list to **CARDS**, press START. UP and DOWN
change the card; START turns the light back on. Hold UP for the menu:

| Menu item | What it does |
| --- | --- |
| Add bar code | UP and DOWN go through 0 to 9 and OK; START types the shown digit or, on OK, finishes. BACK deletes the last digit, or leaves when nothing is typed. Then a text entry asks for the name (preset "Card N"). The new card is shown. A number whose bars would be narrower than 1 px is refused with a short message. |
| Rename | Text entry, preset to the current name. |
| Delete | A yes/no question; on yes the card and its storage key are removed. |

Rename and Delete appear when a card is shown. With no cards the screen says
"No cards" and "Hold UP for menu".

The cards in the build are copied onto the watch the first time the widget is
opened after a new build (when the stamp in `cards.json` differs from the last
imported one). A card of the same name is replaced, otherwise it is appended. A
built-in card that you delete stays deleted until the next build with a changed
list. The glance (the line in the widget list) shows "CARDS" and the names; it
shows only the title until the first full launch.

## Storage

The cards live in `Toybox.Application.Storage`. The phone link writes the same
records, so this format is fixed.

| Key | Value |
| --- | --- |
| `"ids"` | Array of Numbers, the card order |
| `"next"` | Number, the next free id |
| `"seed"` | String, the stamp of the built-in list that was imported |
| `"names"` | Array of Strings, the names in the order of `"ids"`; kept in step on every change, so the glance reads names without loading cards |
| `"c<id>"` | one Dictionary per card, below |

QR card:

```
{ "name": String, "kind": "qr",
  "n": modules per side,
  "g": Array of n Strings, one per row, as hex: the most significant bit of the
       first digit is the leftmost module; the row is padded on the right with
       zero bits to a whole number of hex digits }
```

Bar-code card:

```
{ "name": String, "kind": "bar",
  "t": the typed content,
  "b": String of digits, the widths of bar, gap, bar ... in modules, starting
       with a dark bar }
```

`b` is Code 128 including the start symbol, the check symbol and the stop
pattern, without the quiet zone. If a record has no `b`, the watch works it out
from `t`. The Mac build writes bar codes without `b`, so the watch has the only
encoder.

A card is decoded into drawing runs once, when it becomes the current card.

## Phone link

The Android app in `android/` sends one card at a time through the Connect IQ
Mobile SDK and the Garmin Connect app. The widget is addressed by the id in
`manifest.xml`. `source/PhoneLink.mc` receives the message while the full view
is open (never in the glance); a message that arrives while the widget is
closed waits and is handled when the widget is next opened.
`source/CardInbox.mc` checks it and stores it: a card of the same name is
replaced in place, otherwise the card is appended, and the stored card is
shown.

The message is a dictionary with exactly these keys:

```
QR:   { "v": 1, "id": Number, "name": String, "kind": "qr",  "n": Number, "g": Array of n Strings }
bar:  { "v": 1, "id": Number, "name": String, "kind": "bar", "t": String }
```

| Field | Rule |
| --- | --- |
| `v` | the Number 1 |
| `id` | a Number from 1 to 1,000,000,000, chosen by the phone for each send and repeated in the answer |
| `name` | 1 to 24 characters, no control character, no space at the start or the end |
| `n`, `g` | as in "Storage": 21 <= n <= 177 with (n - 17) divisible by 4; n rows of (n + 3) / 4 lower-case hex digits; the unused low bits of each row are 0; a position square at the top left, the top right and the bottom left and none at the bottom right |
| `t` | 1 to 80 characters, ASCII 32 to 126, and bars at least 1 px per module on this screen |

A Long, a Float or an extra key is refused. For a bar code the phone sends only
the content; the widget computes `b` with its own encoder. The stored record
is built from the checked fields.

The widget answers `{ "id", "ok", "why" }`. `why` is empty when the card was
stored; otherwise it is the first rule that failed, in this order:

| `why` | Meaning |
| --- | --- |
| `format` | not a dictionary, `v` is not 1, `id` missing or out of range, a key missing, an extra key, or a value of the wrong type |
| `name` | the name rule |
| `kind` | neither `"qr"` nor `"bar"` |
| `size` | `n` out of range, or the wrong number of rows, or a row of the wrong length |
| `chars` | a character outside `0-9a-f`, or a padding bit set |
| `shape` | the position squares are not where they belong |
| `content` | `t` empty, longer than 80, or a character outside ASCII 32 to 126 |
| `long` | the bar code is too long to show |
| `full` | the storage write failed |

The answer never holds the name, the grid or the content. On a refusal the
watch shows "Card refused: " and the code, or "Storage full". The answer is the
only proof that a card was stored: the phone's own send status says only that
the message reached the watch.

## Code 128 on the watch

`source/Code128.mc` holds the pattern table and the one encoder:

- all digits, even length: code set C, two digits per symbol;
- all digits, odd length: start in set B with the first digit, switch to C for
  the pairs (a single digit stays in set B);
- anything else: set B for every character; only ASCII 32 to 126 is accepted.

The check symbol is the weighted sum modulo 103; the stop pattern is included.
The module width on the screen is floor((chord - 8) / (modules + 6)) pixels,
where chord is the screen's width at the top edge of the 72 px tall bars and
6 is three quiet modules on each side.

## Does the code change over time?

Some store apps show a code that expires. A copy of such a code stops working.
Take one screenshot now and one a day later, then:

```
bin/cardtool same private/first.png private/second.png
```

It answers "same code" or "different codes" without showing either.

## Checks

`tools/cardtool.swift`, for QR cards:

- The grid has its three position squares at the top left, top right and
  bottom left (a flipped or rotated grid is refused).
- The grid, drawn large, reads back as the original data.
- For a picture: version, mask and error-correction level equal the
  original's, so the watch shows the same symbol, not a re-encoding.
- The preview, at the watch's own pixel size, reads back too.

For bar codes the tool only checks the content (ASCII 32 to 126) and that the
code fits the screen.

`tools/code128_check.swift` checks the Code 128 table that ships. It reads the
table out of `source/Code128.mc`, checks that every pattern is 11 modules wide
(the stop 13) and that all are different, encodes 3,000 random inputs (a third
in each of the three rules), draws each as bars, reads it back with macOS Vision
and compares it with the input. It also reports which symbol values 0 to 102
were used.

```
swiftc -O -o bin/code128_check tools/code128_check.swift
bin/code128_check source/Code128.mc 3000 1
```

Unit tests in `test/Tests.mc` cover the encoder (three fixed vectors from the
check above), hex row to runs, add, rename and delete on the store, and the
once-per-build import. `test/InboxTests.mc` covers the phone link: the check of
a received card with every refusal code, the stored record, a card of the same
name replaced in place, two grids exactly as `tools/cardtool.swift` writes
them, and the link's handler called without a phone. They are not part of the
app. Build them with

```
JUNGLE=test.jungle OUT=bin/CardsTest.prg ./build.sh --unit-test
```

and run them in the Connect IQ simulator (open `<SDK>/bin/ConnectIQ.app`
first): `tools/sim/simtest.sh bin/CardsTest.prg`. They empty the simulator's
storage for this app.

The screens are checked with a second build that presses its own buttons.
`check/CheckApp.mc` is the widget's code started as a watch app (so it opens
on the card view), plus a timer that goes through a fixed script: next card,
menu, add a bar code by typing 13 digits, name it, rename it, delete it,
delete everything. Then it hands the phone link four messages in the phone
app's format: a QR code, a bar code, another QR code under the first name
(which replaces it) and a bar code the watch must refuse. It prints
`step N ...` after each press.
`tools/sim/simrun.sh` runs it and saves a picture of the simulator's window
after every step; `tools/sim/readcodes.swift` then reads the codes back out
of those pictures.

```
JUNGLE=check.jungle OUT=bin/CardsCheck.prg ./build.sh
tools/sim/simrun.sh bin/CardsCheck.prg /tmp/cards-check
```

In the simulator the screen shows the result of a phone step one capture
later: picture N + 1 for step N, and the last picture for the refusal.

The check build has its own app id and manifest (`check-manifest.xml`) and is
never copied to a watch. Its manifest asks for the widget's permission too,
because the widget's source is compiled into it. `monkey.jungle` names
`source` as the only source folder; without that line the compiler takes every
`.mc` file in the project, tests and check code included.

## Layout on the watch

The code sits in the square that fits inside the round screen, with one module
of margin on each side; each module is a whole number of pixels. The name sits
above it, two modules clear, so a scanner still sees a white border.

| Code size | Pixels per module on 280 px |
| --- | --- |
| 21 x 21 | 8 px |
| 29 x 29 | 6 px |
| 37 x 37 | 5 px |
| 45 x 45 | 4 px |

## Requirements

macOS with the Xcode command line tools (`swiftc`), the Connect IQ SDK with the
fenix 6X Pro device files (Garmin's SDK Manager), and a Java runtime for the
compiler (`build.sh` falls back to the one inside Android Studio).

## Copy to the watch

```
./release.sh      # release/Cards.prg: no built-in cards, no debug information
./load.sh         # sends it to GARMIN/APPS over USB (libmtp; see the script's header)
```

`./load.sh` deletes a widget file of the same name in `GARMIN/APPS` after
checking its name, sends the new one, reads it back and compares. Plug the
watch in and quit Garmin Express first.

## Status

Run on 2026-11-13 with Connect IQ SDK 9.3.0, in the SDK's simulator for the
fenix 6X Pro, with sample codes only.

| Check | Result |
| --- | --- |
| Build, type check at level 2 | no errors, no warnings |
| Code 128 table and rules, 3,000 random inputs drawn and read back | 0 failures, all 103 symbol values used |
| Unit tests in the simulator | 22 of 22 pass (8 for the widget, 14 for the phone link) |
| Scripted screen check in the simulator, 22 steps | no error; add, rename and delete change the stored cards as expected; the four phone messages are stored, replaced and refused as expected |
| Codes read back from the simulator's screen | the sample QR code, the sample bar code and the bar code typed with the digit entry all read as their content; so do the two QR codes and the bar code handed to the phone link |
| Glance in the simulator | shows the title; reads the names from storage |
| Release build started in the simulator | starts, no error |
| Phone link: check, store, show and answer, called without a phone | covered by the unit tests and the scripted check above |

Not yet run or not known:

- Nothing has run on a watch. `load.sh` was written without a watch connected
  and has not been run.
- The phone link has not carried a message. No phone app has been connected to
  the simulator or to a watch, so receiving over Bluetooth, the form in which
  the phone's values arrive, a message waiting for a closed widget, and the
  answer reaching the phone are untested. `android/README.md` has the first
  test to run.
- In the simulator the script calls the same functions the buttons call. The
  mapping of the real buttons (a long press of UP opening the menu, START on
  the glance opening the widget) and the watch's own text entry and yes/no
  screens accepting an entry were not pressed by hand.
- Not tried at a store scanner. Bars at 1 px per module (numbers longer than
  about 13 digits) are unlikely to scan.
- Storage limits: the documentation says a stored value is limited to 32 KB
  and that the whole store has a device-dependent limit it does not give. A
  failed write is caught and shown as "Storage full".

Not affiliated with Garmin or any store.
