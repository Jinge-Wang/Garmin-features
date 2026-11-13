#!/bin/sh
# One-time setup: make the developer key that signs your builds, and build
# the small tool that copies the widget to the watch.
# The key is a local file. It is not an account and is not sent anywhere; the
# watch only checks that an app is signed. It stays in private/, which is
# never committed.
set -eu
cd "$(dirname "$0")"
mkdir -p private
if [ -f private/developer_key.der ]; then
    echo "private/developer_key.der is already there"
else
    openssl genrsa -out private/developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER -in private/developer_key.pem -out private/developer_key.der -nocrypt
    chmod 600 private/developer_key.pem private/developer_key.der
    echo "made private/developer_key.der"
fi

# bin/mtp_put sends the widget to the watch over USB (load.sh uses it).
# It needs libmtp; without it the widget can still be built.
if command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix)/include/libmtp.h" ]; then
    mkdir -p bin
    cc -O1 -Wall -I"$(brew --prefix)/include" -L"$(brew --prefix)/lib" -o bin/mtp_put tools/mtp_put.c -lmtp
    echo "built bin/mtp_put"
else
    echo "libmtp not found (brew install libmtp): bin/mtp_put not built; load.sh needs it"
fi
