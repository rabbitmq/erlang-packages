#!/bin/sh

set -ex

# --------------------------------------------------------------------
# Check PGP signing key.
# --------------------------------------------------------------------

gpg -K "$SIGNING_KEY_ID"

cd package-sources && make SUDO="" SIGNING_KEY_ID="$SIGNING_KEY_ID"

mkdir ../packages

# aarch64 Rocky Linux runners are not available on Actions as of Mar 2026
cp RPMS/x86_64/*.rpm ../packages
