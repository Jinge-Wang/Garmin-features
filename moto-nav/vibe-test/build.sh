#!/bin/sh
# Build the app: bin/VibeTest.prg, for the fenix 6X Pro unless DEVICE says otherwise.
# Needs the Connect IQ SDK (installed with Garmin's SDK Manager), a Java
# runtime and a developer key (./setup.sh makes one).
set -eu
cd "$(dirname "$0")"

DEVICE="${DEVICE:-fenix6xpro}"
KEY="${CIQ_KEY:-private/developer_key.der}"
CIQ_HOME="${CIQ_HOME:-$HOME/Library/Application Support/Garmin/ConnectIQ}"

if [ -z "${CIQ_SDK:-}" ]; then
    if [ ! -f "$CIQ_HOME/current-sdk.cfg" ]; then
        echo "No Connect IQ SDK found. Open the SDK Manager, download an SDK and set it as current." >&2
        exit 1
    fi
    CIQ_SDK="$(cat "$CIQ_HOME/current-sdk.cfg")"
fi
if [ ! -d "$CIQ_HOME/Devices/$DEVICE" ]; then
    echo "The device '$DEVICE' is not downloaded. Add it on the SDK Manager's Devices tab." >&2
    exit 1
fi
if [ ! -f "$KEY" ]; then
    echo "No developer key at $KEY. Run ./setup.sh once." >&2
    exit 1
fi

# The compiler is a Java program. Without a system Java, use the runtime that
# ships inside Android Studio when it is there.
if ! java -version >/dev/null 2>&1; then
    JBR="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    if [ -x "$JBR/bin/java" ]; then
        export JAVA_HOME="$JBR"
        export PATH="$JBR/bin:$PATH"
    else
        echo "No Java runtime found. Install one (for example: brew install --cask temurin)." >&2
        exit 1
    fi
fi

mkdir -p bin
# "./build.sh test" builds the unit tests into bin/VibeTest-test.prg (not run
# here; the simulator's test runner or monkeydo runs it) and leaves the app alone.
if [ "${1:-}" = "test" ]; then
    shift
    "${CIQ_SDK%/}/bin/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/VibeTest-test.prg -y "$KEY" -w --unit-test "$@"
    ls -l bin/VibeTest-test.prg
    exit 0
fi
"${CIQ_SDK%/}/bin/monkeyc" -d "$DEVICE" -f monkey.jungle -o bin/VibeTest.prg -y "$KEY" -w "$@"
ls -l bin/VibeTest.prg
