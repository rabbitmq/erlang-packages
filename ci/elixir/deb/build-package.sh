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

distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
release_codename=$(lsb_release -cs)

apt-get install curl gnupg apt-transport-https -y

## Team RabbitMQ's main signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee $keyring_location > /dev/null
## Community mirror of Cloudsmith: modern Erlang repository
curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
## Community mirror of Cloudsmith: RabbitMQ repository
curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides modern Erlang/OTP releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/$distro $release_codename main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/$distro $release_codename main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/$distro $release_codename main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/$distro $release_codename main

## Provides RabbitMQ
##
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/$distro $release_codename main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/$distro $release_codename main

# another mirror for redundancy
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/$distro $release_codename main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/$distro $release_codename main
EOF

cat > /etc/apt/preferences.d/erlang <<EOF
Package: erlang*
Pin: version $ERLANG_VERSION
Pin-Priority: 1001
EOF

## Update package indices
apt-get update -y

## Install Erlang packages
apt-get install -y erlang-base \
                  erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                  erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                  erlang-runtime-tools erlang-snmp erlang-ssl \
                  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

sudo apt-get install rabbitmq-server -y --fix-missing

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
