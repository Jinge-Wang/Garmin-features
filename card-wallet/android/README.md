# Card Loader: send a card from an Android phone to the watch

An Android app for the Cards widget. It reads a QR code or a bar code with the
camera or from a picture, on the phone, asks for a name, and sends the card to
the widget over the Garmin Connect app's Bluetooth link. Once the widget is on
the watch, no computer is needed to add or replace a card.

## What leaves the phone

| Step | Where it runs | What leaves this app |
| --- | --- | --- |
| Read the code from the camera or a picture | this app, with the ZXing library | nothing |
| Rebuild the QR symbol as a grid | this app | nothing |
| Send the card | Connect IQ Mobile SDK, to the Garmin Connect app on the same phone | the card, to Garmin Connect |
| Deliver it | Garmin Connect, over Bluetooth | the card, to the watch |

**The app has no internet permission.** Its manifest does not request
`android.permission.INTERNET`, and Android gives an app without it no network
socket, not even to the phone itself. A library can bring a permission in
through its own manifest, so the build reads the merged manifest and fails if
INTERNET is in it (`verifyNoInternet` in `app/build.gradle.kts`).

Permissions in the built APK, read with `aapt2 dump permissions` on 2026-11-13:

| Permission | Why it is there |
| --- | --- |
| `android.permission.CAMERA` | scanning; asked for when you tap "Scan with the camera" |
| `app.cardloader.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | declared by the AndroidX library for its own receivers; private to this app |

The app keeps nothing. No file, setting or log line holds a code; a card
exists in memory from the scan until you leave the review or the result. It
uses no Google Play Services, no ML Kit, no analytics and no network library.

**The limit of this guarantee.** The card passes through the Garmin Connect
app, which is Garmin's software and has internet access. Garmin documents this
path as a relay between a phone app and a watch app. This project cannot see
what Garmin Connect does with a message. If that is not acceptable for a card,
load it over USB instead (the main README, "Use").

## Use

1. The watch needs the Cards widget with the phone link (`../release.sh`,
   `../load.sh`), and the phone needs Garmin Connect with the watch paired.
2. Open Card Loader. The first line says whether the watch is connected.
3. Tap **Scan with the camera** and point at the code, or tap **Pick a
   picture** and choose a screenshot or a photo.
4. Review: the app shows what it read and how large it will be on the watch.
   Type the name the card has on the watch (1 to 24 characters). A card with
   the same name on the watch is replaced.
5. Tap **Send to watch**. The next screen shows three steps as they happen:

   | Line | Meaning |
   | --- | --- |
   | Handed to Garmin Connect | the message left this app |
   | Reached the watch | Garmin Connect reports the transfer done |
   | Stored on the watch as *name* | the widget checked the card, stored it and answered |

   Only the third line proves that the card is on the watch. The widget
   handles a message while it is open. If no answer comes within 20 seconds,
   open it on the watch (widget list, CARDS, START); the card is stored then,
   and the screen keeps listening while it is open. **Ask the watch to open
   the widget** makes the watch show a prompt.

## What it reads

| Code | What is sent | What the watch shows |
| --- | --- | --- |
| QR code | the module grid of the same symbol: same version, mask pattern, error-correction level and data | the identical symbol |
| Code 128 bar code | its content | the same bar code, drawn by the watch's encoder |
| Code 39, Code 93, EAN-13, EAN-8, UPC-A, UPC-E, ITF, Codabar | its content | the same content as a Code 128 bar code |
| PDF417, Aztec, Data Matrix | nothing; the app says the watch does not show them | |

A QR code is not copied pixel by pixel. The app decodes what the camera saw to
its error-corrected data, reads the mask pattern and level from the code's
format information, and generates the symbol again (`codec/QrExactCopy.kt`,
`codec/QrMatrixBuilder.kt`). `tools/cardtool.swift` does the same on the Mac,
and the tests below check that both give the same grid. Before a rebuilt grid
is accepted it must decode to the same data, have its three position squares
in place, and differ from what the camera saw in fewer than a quarter of the
modules.

A bar code of another symbology becomes Code 128 on the watch. Most scanners
read both; test it at the scanner before leaving the card at home. The content
must be ASCII 32 to 126, at most 80 characters, and short enough for 1 px per
module on the watch: 40 digits, or 20 other characters.

From the camera a QR code is taken at the first good frame. A bar code is taken
after three frames in a row gave the same content, because the modules of a
blurred QR code can read as a short bar code.

Limits: the sizes are those of the fenix 6X Pro (280 px screen). A store app
that blocks screenshots leaves only the camera, and a phone cannot photograph
its own screen. Some codes change over time; see the main README.

## Build

Needs a JDK (17 or newer; the one inside Android Studio works) and the Android
SDK with platform 37 and build-tools 36. Point `JAVA_HOME` at the JDK and
`ANDROID_HOME` at the SDK, or write `sdk.dir` into `local.properties` (it is
git-ignored: it holds a path of your computer).

```
./gradlew assembleDebug
```

writes `app/build/outputs/apk/debug/app-debug.apk` and prints the permission
list. The first build downloads its libraries, among them the Connect IQ
Mobile SDK 2.4.0 from Maven Central.

| Item | Value |
| --- | --- |
| Application id | `app.cardloader` |
| Minimum Android | 11 (API 30) |
| Target API | 37 |
| Libraries | ZXing core 3.5.3, CameraX 1.3.4, Jetpack Compose, Connect IQ Mobile SDK 2.4.0 |
| Watch app it addresses | the id in `../manifest.xml` |

The Connect IQ SDK brings one `<queries>` entry (the Garmin Connect package)
and one exported service that Garmin Connect binds to. It also contains a mode
for the Connect IQ simulator that opens a socket over ADB. This app never
selects that mode, and without the INTERNET permission Android would refuse
the socket, so this build cannot talk to the simulator.

## Tests

```
./gradlew testDebugUnitTest
```

They run on the computer, without a phone. 47 tests, 0 failed, on 2026-11-13
(one run of `./gradlew clean assembleDebug testDebugUnitTest`, 68 s, JDK 25 on
an Apple silicon Mac).

| Test class | What it shows | Tests |
| --- | --- | --- |
| `FixtureEqualityTest` | for 8 dummy QR pictures and 3 bar numbers, the record equals what `tools/cardtool.swift` writes, and its message passes the phone link's rules | 1 |
| `ExactCopyTest` | the rebuilt grid equals ZXing's encoder matrix for versions 1, 2, 7, 10, 15 and 25, four levels and eight masks (192 symbols); also with two modules flipped, mirrored, and two codes in one picture | 6 |
| `PictureSizeSweepTest` | 9,856 clean pictures (13 versions, four levels, eight masks, 2 to 40 px per module), each read in one try as the identical symbol | 1 |
| `ContractTest` | every refusal code of the phone link, the valid messages, the message's keys and types | 17 |
| `GridTest` | hex rows, position squares, the bar width estimate | 7 |
| `FrameFilterTest` | camera frames: a QR code at once, a bar code after three equal frames | 3 |
| `SendControllerTest` | the send steps against a stand-in for the watch: delivery, answer matched by id, refusal, no answer | 8 |
| `TextsTest` | the status texts | 3 |
| `HomeScreenTest` | the real activity starts with the real SDK and no Garmin Connect, and says so | 1 |

`fixtures/` holds the pictures, the list given to the Mac tool and the tool's
answer (`expected.json`). `fixtures/make_fixtures.sh` rebuilds them on macOS
and also checks that the tool's grid equals the grid each picture was drawn
from. Every code in it is a dummy. Do not edit `expected.json` by hand: it is
what the phone's result is measured against.

The sweep is there because of a fault it found. ZXing's detector chooses three
position squares, and data modules can look like one. With only the detector's
first choice, 176 of the 9,856 pictures were not read. The reader now also
goes through the other combinations, and reads a very small picture enlarged.

## First test on a phone and a watch

Nothing here has run on a phone or a watch yet. Use dummy codes for the first
run: the pictures in `fixtures/` and any packaged product's bar code.

Before you start: the watch has the widget from `../release/Cards.prg` (built
after the phone link was added); the phone has Garmin Connect, and the watch is
paired and connected. Install the app with USB debugging on:

```
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

or copy `../release/CardLoader.apk` to the phone over USB and open it there.

| Step | Do | Expect |
| --- | --- | --- |
| 1 | Open Card Loader | The first line names the watch and says it is connected |
| 2 | Open `fixtures/qr-medium-m.png` on the computer, large. Tap **Scan with the camera**, allow the camera, point at it | Review: "QR code, version 3, 29 x 29 modules", "On the watch each module is 6 px wide", a drawing of the code |
| 3 | Open the widget on the watch (widget list, CARDS, START). Name the card `Test QR`, tap **Send to watch** | Phone: the three lines end with "Stored on the watch as Test QR". Watch: the card "Test QR" |
| 4 | Read the watch's screen with any QR reader on another phone | `SAMPLE-CARD-0000 dummy membership 0123456789` |
| 5 | Copy `fixtures/qr-screenshot.png` to the phone over USB. **Pick a picture**, choose it, name it `Test QR` again, send | Watch: the same number of cards; "Test QR" now reads `SAMPLE-CARD-0001 dummy membership screenshot` |
| 6 | Close the widget on the watch (BACK). Scan the bar code of a packaged product and hold still. Name it `Test bar`, send | Review: "Bar code, 13 characters, read as EAN-13" for a 13-digit code, and the note about Code 128. Phone: "Reached the watch", and after 20 seconds "No answer yet" |
| 7 | Open the widget on the watch | Phone: "Stored on the watch as Test bar". Watch: the bars with the number under them |
| 8 | With the widget closed, tap **Ask the watch to open the widget** | The watch shows a prompt, or the phone says that it did not |
| 9 | On the watch, hold UP and choose Delete for each test card | "No cards", or your own cards only |

If a step fails, note the lines of the phone's Sending screen word for word,
what the watch shows, the version of Garmin Connect and the watch's software
version.

Then load a real card yourself. If you work with an AI assistant, do not let
it see the phone's screen, a screenshot of it or the picture you pick while a
real card is on it: whatever it reads is sent to its provider.

## Status

Run on 2026-11-13 on the computer, with dummy codes only:

| Check | Result |
| --- | --- |
| `./gradlew assembleDebug` | builds; APK 31.9 MB (debug build, not shrunk) |
| Unit tests | 47 of 47 pass |
| Permissions in the APK | CAMERA and the AndroidX private permission; no INTERNET |
| Home path, user name or host name inside the APK | none found (all 511 files searched) |

Not yet run or not known:

- Nothing has run on a phone. The camera, the permission question, the picture
  picker and every screen after the first were written from the documentation.
- The Connect IQ SDK has not met a real Garmin Connect app: finding the watch,
  its connection state, sending, the widget's answer and the open request are
  untested. Whether Garmin Connect passes a message to a widget that was copied
  to the watch by USB and not installed from Garmin's store is reported to
  work by others and was not tried here.
- The largest message that gets through is not known. A version 3 code is
  about 0.3 KB of text, version 16 about 1.7 KB, version 40 about 8 KB.
- Not tried on Android 11; the phone's own picture formats (for example HEIC)
  were not tried.
- The Android lint checks were not run.

Not affiliated with Garmin or any store.
