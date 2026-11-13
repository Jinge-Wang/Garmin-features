# Vibe test: turn cues by wrist vibration, a one-ride experiment

A small Connect IQ watch app for the fenix 6X Pro. It fires "left" and "right"
vibration patterns at fixed intervals, so a rider can learn by feel two
things before any navigation app is built:

1. Are the watch's vibrations felt at all through a jacket cuff while riding?
2. Can a "left" pattern be told from a "right" pattern?

The app has no permissions, no GPS, no sensors, no recording and no tones.
Nothing is sent anywhere.

## Buttons

| Screen | Button | Action |
| --- | --- | --- |
| Setup | UP / DOWN | Interval between cues: 20, 30, 45 or 60 s (default 30) |
| Setup | Hold UP | Menu: "Pattern set" flips A and B; "Last run" shows the stored summary |
| Setup | START | Begin the run |
| Run | START | Fire the next cue now |
| Run | BACK | End the run, show the summary |
| Summary | BACK | Leave the app (from "Last run": back to the menu) |

The run screen shows a black arrow on white for the last cue fired, the
seconds to the next cue and the number of cues fired.

## Cues and patterns

Cues come in a fixed order, repeated: **L, R, R, L, L, R**. The rider can
judge by feel alone and check the order at a stop. Every pulse runs the motor
at full strength (duty cycle 100); in a gap the motor is off.

| Set | Left | Right |
| --- | --- | --- |
| A | one pulse, 800 ms | three pulses of 200 ms, gaps of 150 ms (800 ms in all) |
| B | two pulses of 400 ms, gap of 200 ms (1000 ms in all) | four pulses of 120 ms, gaps of 120 ms (840 ms in all) |

Each pattern uses at most 7 of the 8 vibration steps the watch accepts in one call.

## Ride protocol

1. At home, build and copy the app (below). Check that vibration is on in the
   watch's sound settings. Put the phone on Do Not Disturb for the ride, so
   that phone notifications do not add vibrations of their own. Wear the
   watch on the wrist you ride with, under or over the cuff as you normally
   would.
2. While stopped, open the app, choose the interval and the set, press START,
   and put the hands back on the bars.
3. Do not operate the watch while moving. The cues come by themselves. Do not
   look at the screen to judge a cue; feel first.
4. Ride one stretch with set A, stop, press BACK, and read the summary. Repeat
   with set B (hold UP, "Pattern set", then START).
5. At each stop, say aloud which cue you felt last and compare with the arrow.
   Stop and compare the letters of the summary with what you noted.
6. Afterwards, write down:
   - how many cues were felt out of the count shown on the watch;
   - whether left and right were distinguishable, and how often you guessed wrong;
   - which set was clearer;
   - the speeds and road surfaces (smooth tarmac, rough road, cobbles, highway).

## Build

Needs the Connect IQ SDK (Garmin's SDK Manager, with the fenix 6X Pro
device downloaded) and a Java runtime.

```
./setup.sh          # once: makes the signing key in private/
./build.sh          # makes bin/VibeTest.prg
./build.sh -l 2     # the same with type checking at level 2 (no warnings)
./build.sh test     # builds the unit tests into bin/VibeTest-test.prg
```

The unit tests (`source/CuesTest.mc`) check the cue order and the pattern
lists. `./build.sh test` only compiles them; run them in the simulator's test
runner when wanted.

## Copy to the watch

Connect the watch by USB and copy `bin/VibeTest.prg` into the watch's
`GARMIN/APPS` folder. Eject the watch; the app appears in the app list as
"Vibe test".

## Log

Each cue prints one line with `System.println`: seconds since the start, the
letter and the set, for example `60 s R set A`. In the simulator this shows
the schedule.

## Status

Run on 2026-11-13 with Connect IQ SDK 9.3.0, in the SDK's simulator for the
fenix 6X Pro.

| Check | Result |
| --- | --- |
| Build, type check at level 2 | no errors, no warnings |
| Unit tests in the simulator (cue order, pattern lists) | 2 of 2 pass |
| Scripted screen check in the simulator (`check/CheckVibeApp.mc`, built with `check.jungle`) | no error: interval and pattern set change, a run starts, START fires a cue, the timed cue follows 20 s later, the summary and "Last run" show the run |

**It has not run on a watch.** Not yet known: whether the 0% gaps are played
as true pauses by the watch's motor, how strong the pulses feel, and whether
the app keeps running on screen for an hour. In the simulator the script calls
the same functions the buttons call; the real buttons were not pressed.

`monkey.jungle` names `source` as the only source folder, so the check code in
`check/` is never part of the app.
