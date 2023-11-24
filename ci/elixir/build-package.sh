#!/bin/sh
# vim:sw=2:et:

set -ex

test "$ERLANG_VERSION"

INITIAL_DIRECTORY=$PWD

# --------------------------------------------------------------------
# Install package building tools.
# --------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y tzdata

echo "Europe/London" | tee -a /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  apt-transport-https \
  devscripts \
  equivs \
  git \
  git-buildpackage \
  gnupg \
  lsb-release \
  curl

# --------------------------------------------------------------------
# Setup RabbitMQ's Erlang Debian packages repository.
# --------------------------------------------------------------------

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E495BB49CC4BBE5B

keyring_location=/usr/share/keyrings/rabbitmq-rabbitmq-erlang-archive-keyring.gpg

curl -1sLf "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key" |  gpg --dearmor > ${keyring_location}
curl -1sLf "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/config.deb.txt?distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')&codename=$(lsb_release -cs)" > /etc/apt/sources.list.d/rabbitmq-rabbitmq-erlang.list

cat > /etc/apt/preferences.d/erlang <<EOF
Package: erlang*
Pin: version $ERLANG_VERSION
Pin-Priority: 1001
EOF

apt-get update

# --------------------------------------------------------------------
# Check PGP signing key.
# --------------------------------------------------------------------

gpg -K "$SIGNING_KEY_ID"

# --------------------------------------------------------------------
# Prepare package.
# --------------------------------------------------------------------

cd elixir-sources

cp -a ../package-sources/debian .

branch=elixir-debian-package-by-rabbitmq
version=$(git describe --tags | \
  sed -E -e 's/^v//' -e 's/-/~/' -e 's/-/./')
tag=v$version

git rev-parse "$tag" -- >/dev/null 2>&1 || git tag "$tag"
git checkout -b "$branch"

# --------------------------------------------------------------------
# Configure git-buildpackage.
# --------------------------------------------------------------------

cat > ~/.gbp.conf <<EOF
[DEFAULT]
upstream-tag = v%(version)s
EOF

# --------------------------------------------------------------------
# Build package.
# --------------------------------------------------------------------

# Workaround to create XZ archives in the final .deb files
# Ubuntu 22.04 creates ZSTD-compressed files, which Cloudsmith does not support yet.
# The "--git-builder='debuild --preserve-envvar PATH -i -I'" option in
# the gbp buildpackage command is mandatory for the patched dpkg-deb script to be used.
echo '#!/bin/bash
/usr/bin/dpkg-deb -Zxz $@' > /usr/local/bin/dpkg-deb
chmod u+x /usr/local/bin/dpkg-deb

export DEB_BUILD_OPTIONS=nocheck

mk-build-deps -i \
  -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y'
rm -f elixir-lang-build-deps*

gbp buildpackage \
  --git-ignore-new \
  --git-debian-branch="$branch" \
  --git-builder='debuild --preserve-envvar PATH -i -I' \
  -k"$SIGNING_KEY_ID"

# --------------------------------------------------------------------
# Move final package.
# --------------------------------------------------------------------

cd $INITIAL_DIRECTORY

mkdir packages

mv *.dsc *.changes *.deb packages
