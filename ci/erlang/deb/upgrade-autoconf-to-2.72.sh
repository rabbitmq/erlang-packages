#!/bin/sh
# vim:sw=2:et:

set -ex

# shellcheck disable=SC3043
local autoconf_deb_path="/tmp/autoconf.deb"
curl -fL https://launchpad.net/ubuntu/+archive/primary/+files/autoconf_2.72-3_all.deb -o "$autoconf_deb_path"
dpkg -i "$autoconf_deb_path"
rm "$autoconf_deb_path"
