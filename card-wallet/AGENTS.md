# Instructions for an agent: put Cards on the watch and Card Loader on the phone

You are at a computer where the owner's Garmin fenix 6X Pro and Android phone
can be plugged in by USB. Your job is to install two files from this folder
and run a first test with sample codes. Everything you need is in this
repository; nothing has to be built.

| File | What it is | Goes to |
| --- | --- | --- |
| `release/Cards.prg` | the Cards widget (bar codes and QR codes on the watch); it holds no card | the watch, folder `GARMIN/APPS` |
| `release/CardLoader.apk` | the phone app that scans a code and sends it to the widget; it has no internet permission | the phone |
| `../moto-nav/vibe-test/release/VibeTest.prg` | a separate test app (vibration cues for a motorcycle ride) | the watch, same folder, only if the owner asks for it |

`release/Cards.prg` is built for the fenix 6X Pro only. For another watch,
rebuild it (see "Building from source").

## Rules

1. **Ask the owner before every step that changes a device**: each file sent
   to the watch, each install on the phone, each delete. Say what you are
   about to do and wait for a yes.
2. **Never look at a real card.** The owner's card codes must not leave their
   devices, and whatever you read is sent to your provider. Do not open the
   owner's screenshots or photos of cards, do not capture the phone's or the
   watch's screen while a real card is on it, do not print a code's content.
   Test with the sample codes named below. The owner loads real cards alone.
3. **Touch one place on the watch**: the file you send into `GARMIN/APPS`.
   Read anything you need; change nothing else. This watch carries other
   custom files from another project in this repository.
4. No account, sign-in or network service is needed for any step. If a step
   seems to need one, stop and tell the owner.
5. Commit or push nothing unless the owner tells you to.

## What has been checked, and what has not

Checked on 2026-11-13 on the build computer, with sample codes only:

- The widget: builds without warnings; 22 of 22 unit tests pass in Garmin's
  simulator for this watch; a scripted run of every screen passes; the codes
  read back correctly from the simulator's screen, including cards arriving in
  the phone's message format.
- The phone app: 47 of 47 unit tests pass; the APK requests the camera
  permission only (plus one private AndroidX permission) and not INTERNET.

**Not checked: nothing has run on a real watch or a real phone.** The watch
loader script `load.sh` has never run against a watch. No message has
travelled from a phone to the watch. Expect to find problems; when you do,
stop, collect what "If something fails" lists, and report it. Do not work
around a failure by changing files on the watch.

## Step 1: the watch

The watch is an MTP device. It does not mount as a disk on macOS or Linux.
Before you start, on any system: plug the watch in with its charging cable,
and quit Garmin Express and any other program that talks to the watch (their
background services hold it).

### macOS or Linux, with the script

Needs libmtp (`brew install libmtp`, or your distribution's `libmtp` and
`mtp-tools` packages) and a C compiler. The MTP tools need direct USB access:
from a sandboxed shell they report "No raw devices found".

```
./setup.sh                      # builds bin/mtp_put; also makes a signing key, which you can ignore
mtp-detect | grep Model         # read only; expect: Model: fenix 6X Pro
mtp-folders | grep -i -B1 apps  # read only; expect APPS one level under GARMIN
```

If both read-only commands show what is expected, ask the owner, then:

```
./load.sh release/Cards.prg
```

It finds `GARMIN/APPS`, deletes a file named `Cards.prg` there if one exists
(after checking the name), sends the new file, reads it back and compares.
If the script cannot find the folder or prints anything unexpected, stop: it
was written without a watch connected. You can do its steps by hand with
`mtp-folders` (folder ids), `mtp-files` (file ids, names, parents) and
`bin/mtp_put send <APPS folder id> Cards.prg release/Cards.prg`.

### Windows

The watch appears in File Explorer under "This PC" as a portable device. Open
its internal storage, then `GARMIN`, then `APPS` (the name may show as
`Apps`). After the owner's yes, copy `release\Cards.prg` into that folder,
replacing an older `Cards.prg` if there is one.

### Linux, without the script

A file manager with MTP support shows the watch; copy the file into
`GARMIN/APPS` as on Windows.

### After copying

Unplug the watch and wait until it has returned to the watch face. Then, on
the watch (the buttons are on the README's "Use" list):

1. From the watch face press UP or DOWN to go through the widget list. Look
   for **CARDS**.
2. If it is not in the list, hold UP to open the menu and add it under the
   watch's widget settings. (General knowledge about this watch, not checked
   here; the owner knows the watch.)
3. Press START on CARDS. With no card it shows "No cards" and "Hold UP for
   menu".
4. Hold UP, choose "Add bar code", type `0000 1234 5678` without the spaces
   (UP and DOWN change the digit, START takes it, choose OK at the end), name
   it `Test`. Expect a bar code with the number under it.

## Step 2: the phone

Needs `adb` (Android platform tools). The owner turns on USB debugging
(Settings, About phone, tap the build number seven times; then Developer
options, USB debugging) and accepts the computer on the phone's screen. The
phone needs the Garmin Connect app with the watch paired; the owner has it.

```
adb devices                              # read only; expect one device, state "device"
```

Ask the owner, then:

```
adb install -r release/CardLoader.apk
```

Check what was installed (read only):

```
adb shell dumpsys package app.cardloader | grep -i -E "versionName|permission"
```

Expect version 0.1.0 and no line with `android.permission.INTERNET`. If
INTERNET is listed, stop, uninstall the app after the owner's yes
(`adb uninstall app.cardloader`) and report it.

If `adb install` says `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, an older build
signed on another computer is installed; uninstall it after the owner's yes
and install again. Without `adb`, the owner can copy the APK to the phone and
open it there.

## Step 3: first test, with sample codes

Follow the table "First test on a phone and a watch" in `android/README.md`.
It uses the sample pictures in `android/fixtures/` (open one large on the
computer's screen and scan it with the phone) and the bar code of any
packaged product. It ends with deleting the test cards.

The points most likely to fail, since they were never tried:

| What | What to watch for |
| --- | --- |
| The phone app finding the watch | The first line of the app should name the watch as connected |
| A message reaching a widget that was copied by USB and not installed from Garmin's store | The third line, "Stored on the watch as ...", only appears if this works |
| The widget being closed when a card is sent | Open it on the watch; the card should be stored then |

When the test passes, tell the owner it is ready. The owner then scans their
real cards alone, with no agent looking at either screen.

## The vibration test app

Only if the owner asks. It is installed the same way as the widget:

```
./load.sh ../moto-nav/vibe-test/release/VibeTest.prg
```

It appears in the watch's app list as "Vibe test". Its README
(`../moto-nav/vibe-test/README.md`) has the ride protocol. The owner runs the
ride; do not start it for them.

## If something fails

Stop and report, with:

- the exact command or step, and everything it printed;
- for the watch: the output of `mtp-detect | grep -E "Model|Device version"`
  and of `mtp-folders`, and the file `GARMIN/APPS/LOGS/CIQ_LOG.YML` if it
  exists (copy it off with `mtp-getfile <file id> ciq_log.yml`; read only);
- for the phone: the lines of the app's Sending screen word for word (they
  hold no card content), the Android version and the Garmin Connect version;
- what the watch's screen shows, described in words if a real card could be on
  it.

To undo: delete `Cards.prg` from `GARMIN/APPS` (the cards stored by the
widget go with it), and `adb uninstall app.cardloader`. Both need the owner's
yes.

## Building from source

Not needed for the install. If the owner asks for a change or another watch:

- Widget: `README.md` (sections "Use", "Checks", "Copy to the watch").
  It needs Garmin's Connect IQ SDK, which is downloaded with Garmin's SDK
  Manager after signing in with a Garmin account; the owner signs in.
  `./setup.sh`, `./build.sh -l 2`, `./release.sh`. The checks run in the SDK's
  simulator with `tools/sim/simtest.sh` and `tools/sim/simrun.sh`.
- Phone app: `android/README.md` ("Build", "Tests"). `./gradlew assembleDebug`
  fails by itself if the INTERNET permission appears in the merged manifest.
