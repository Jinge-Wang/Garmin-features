#!/bin/sh
# One-time setup: make the developer key that signs your builds.
# The key is a local file. It is not an account and is not sent anywhere; the
# watch only checks that an app is signed. It stays in private/, which is
# never committed.
set -eu
cd "$(dirname "$0")"
mkdir -p private
if [ -f private/developer_key.der ]; then
    echo "private/developer_key.der is already there"
    exit 0
fi
openssl genrsa -out private/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in private/developer_key.pem -out private/developer_key.der -nocrypt
chmod 600 private/developer_key.pem private/developer_key.der
echo "made private/developer_key.der"
