#!/bin/sh
# vim:sw=2:et:

set -ex

test "$CLOUDSMITH_ORG"
test "$CLOUDSMITH_REPOSITORY"

# --------------------------------------------------------------------
# Install a few tools.
# --------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y tzdata

echo "Europe/London" | tee -a /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

apt-get install -y --no-install-recommends \
  ca-certificates \
  apt-transport-https \
  dpkg-dev \
  gnupg \
  lsb-release \
  curl

# --------------------------------------------------------------------
# Determine the Erlang version to pin.
# --------------------------------------------------------------------

cd package-sources

wanted_version=$(dpkg-parsechangelog | \
  awk '/^Version:/ { print $2; }')

test "$wanted_version"

cd ..

# --------------------------------------------------------------------
# Setup RabbitMQ's Erlang Debian packages repository.
# --------------------------------------------------------------------

keyring_location=/usr/share/keyrings/rabbitmq-rabbitmq-erlang-archive-keyring.gpg
curl -1sLf "https://dl.cloudsmith.io/public/$CLOUDSMITH_ORG/$CLOUDSMITH_REPOSITORY/gpg.E495BB49CC4BBE5B.key" |  gpg --dearmor > ${keyring_location}
curl -1sLf "https://dl.cloudsmith.io/public/$CLOUDSMITH_ORG/$CLOUDSMITH_REPOSITORY/config.deb.txt?distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')&codename=$(lsb_release -cs)" | tee --append /etc/apt/sources.list.d/rabbitmq-rabbitmq-erlang.list

tee -a /etc/apt/preferences.d/rabbitmq-erlang > /dev/null <<EOT
Package: erlang*
Pin: version $wanted_version
Pin-Priority: 1000
EOT

apt-get update -y

# --------------------------------------------------------------------
# Install and test Erlang package.
# --------------------------------------------------------------------

apt-get install -y --no-install-recommends erlang-base erlang-mnesia erlang-runtime-tools erlang-asn1 erlang-crypto erlang-public-key erlang-ssl \
                                           erlang-syntax-tools erlang-snmp erlang-os-mon erlang-parsetools \
                                           erlang-inets erlang-tools erlang-eldap erlang-xmerl \
                                           erlang-dev erlang-edoc erlang-eunit erlang-erl-docgen erlang-src \
                                           erlang

# Display and verify the version.

installed_version=$(dpkg -l erlang-base | awk '/^ii/ { print $3; }')
test "$installed_version" = "$wanted_version"

erl -version

branch=$(erl -noinput -eval 'io:format(erlang:system_info(system_version)), halt().' | \
  awk '{ v = $2; sub(/^R/, "", v); sub(/B.*/, "", v); print v; }')
case "${wanted_version#*:}" in
  $branch.*)
    ;;
  *)
    echo "Erlang ($branch) does not match package ($wanted_version)" 1>&2
    exit 1
    ;;
esac
