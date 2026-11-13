# Garmin features

Independent projects for Garmin watches. Each project is one folder with its own
README, scripts and requirements. No project depends on another. The repository
contains no files copied from a Garmin device; where a project needs one, it
reads it from the user's own watch.

| Project | What it does | Tested on |
| --- | --- | --- |
| [cn-characters-support](cn-characters-support/) | Chinese reading support: adds a picture of every Chinese character to the emoji picture-font table, so Chinese in phone notifications is drawn | fenix 6X Pro, worldwide edition, firmware 28.02 |
| [card-wallet](card-wallet/) | Cards: a watch widget that keeps membership bar codes and QR codes, with rename, delete and number entry on the watch, and Card Loader, an Android app with no internet permission that scans a code and sends it to the widget. Ready-made files in `card-wallet/release/` | fenix 6X Pro in the Connect IQ simulator (SDK 9.3.0); not yet on a watch or a phone |
| [moto-nav/vibe-test](moto-nav/vibe-test/) | Vibe test: a watch app that fires left and right vibration patterns on a timer, to learn on one ride whether wrist cues can be felt on a motorcycle. Ready-made file in `moto-nav/vibe-test/release/` | fenix 6X Pro in the Connect IQ simulator (SDK 9.3.0); not yet on a watch |

These projects are not affiliated with Garmin.

## License

The code and documentation are under the MIT License (see `LICENSE`). Data
derived from a third-party font carries that font's license; each project's
README says where. `card-wallet/release/CardLoader.apk` contains third-party
libraries under their own licenses (ZXing, AndroidX, Garmin's Connect IQ
Mobile SDK).

An agent that is asked to install these on a watch or a phone starts with
`AGENTS.md`.
