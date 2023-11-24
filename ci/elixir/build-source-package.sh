#!/bin/sh
# vim:sw=2:et:

set -ex

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
  devscripts \
  equivs \
  git \
  git-buildpackage \
  gnupg \
  lsb-release \
  wget \
  dput

# --------------------------------------------------------------------
# Setup RabbitMQ's PPA repository.
# --------------------------------------------------------------------

echo "deb http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/rabbitmq-erlang.list
wget -O- https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-launchpad-ppa-signing-key.asc | apt-key add -

cat > /etc/apt/preferences.d/rabbitmq-erlang <<EOF
Package: erlang*
Pin: version $ERLANG_VERSION
Pin-Priority: 1000
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

# e.g. 1.13.4
changelog_version=$(dpkg-parsechangelog | \
  sed -n 's/^Version: \(.*\)-[^-]*$/\1/p')
# e.g. 1.13.4-1rmq1ppa1~ubuntu18.04.1
package_version="$changelog_version-1rmq1ppa1~ubuntu$DISTRIBUTION_VERSION.1"
# e.g. elixir-lang_1.13.4.orig.tar.gz
source_filename="$(echo $SOURCE_PROJECT_NAME)_$changelog_version.orig.tar.gz"

for dist_version in $DISTRIBUTION_VERSIONS; do 
    source_url="https://launchpad.net/~$LAUNCHPAD_ID/+archive/ubuntu/$PPA_REPOSITORY/+sourcefiles/$SOURCE_PROJECT_NAME/$changelog_version-1rmq1ppa1~ubuntu$dist_version.1/$source_filename"
    set +e
    wget --output-document "$source_filename" "$source_url"
    if [ $? != 0 ]; then
        rm $source_filename
    fi
    set -e
    if [ -f $source_filename ]; then
        echo "Found existing source file: $source_url"
        mv $source_filename ../
        break
    fi
done

sed -i "1 s/unstable/$DISTRIBUTION_CODENAME/" debian/changelog
sed -i "1 s/stable/$DISTRIBUTION_CODENAME/" debian/changelog
sed -E -i "1 s/\([0-9a-zA-Z:\.\-]+\)/($package_version)/" debian/changelog

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

mk-build-deps -i \
  -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y'
rm -f elixir-lang-build-deps_*.*

if [ -f ../$source_filename ]; then
# orig file already in the repository
gbp buildpackage \
  --git-builder="debuild -S -sd -i -I" \
  --git-ignore-new \
  --git-debian-branch="$branch" \
  -k"$SIGNING_KEY_ID" \
  --git-no-create-orig
else
# orig file must be generated and upload
gbp buildpackage \
  --git-builder="debuild -S -i -I" \
  --git-ignore-new \
  --git-debian-branch="$branch" \
  -k"$SIGNING_KEY_ID"
fi

# --------------------------------------------------------------------
# Move final package.
# --------------------------------------------------------------------

cd ..

mkdir source-package-out
mv *.dsc source-package-out
mv *.tar.xz source-package-out
mv *.tar.gz source-package-out
mv *_source.* source-package-out
cd source-package-out

# --------------------------------------------------------------------
# Configure dput.
# --------------------------------------------------------------------

cat > ~/.dput.cf <<EOF
[rabbitmq-ppa]
fqdn = ppa.launchpad.net
method = ftp
login = anonymous
incoming = ~$LAUNCHPAD_ID/ubuntu/$PPA_REPOSITORY/$DISTRIBUTION_CODENAME
allow_unsigned_uploads = 0
EOF

dput rabbitmq-ppa $(ls *.changes)

set +e
rm $source_filename
echo "Waiting until source file is available"
SOURCE_WAIT_TIMEOUT=600
SOURCE_RETRY_INTERVAL=20
SOURCE_WAITED_TIME=0
SOURCE_URL="https://launchpad.net/~$LAUNCHPAD_ID/+archive/ubuntu/$PPA_REPOSITORY/+sourcefiles/$SOURCE_PROJECT_NAME/$package_version/$source_filename"

until [ $SOURCE_WAITED_TIME -ge $SOURCE_WAIT_TIMEOUT ]
do
    sleep $SOURCE_RETRY_INTERVAL
    wget --spider "$SOURCE_URL"
    if [ $? -eq 0 ]; then
        wget --progress dot:giga --output-document "$source_filename" "$SOURCE_URL"
    fi
    if [ -f $source_filename ]; then
        SOURCE_WAITED_TIME=$SOURCE_WAIT_TIMEOUT
    fi
    SOURCE_WAITED_TIME=$((SOURCE_WAITED_TIME+SOURCE_RETRY_INTERVAL))
done

if [ ! -f $source_filename ]; then
    echo "Could not download source file, exiting normally"
    exit 0
fi

set -e
