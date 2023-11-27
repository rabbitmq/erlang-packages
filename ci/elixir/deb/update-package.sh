#!/bin/sh
# vim:sw=2:et:

set -ex

# --------------------------------------------------------------------
# Install tools.
# --------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y tzdata

echo "Europe/London" | sudo tee -a /etc/timezone > /dev/null
sudo dpkg-reconfigure -f noninteractive tzdata

sudo apt-get install -y --no-install-recommends \
  dpkg-dev \
  git \
  rsync

# --------------------------------------------------------------------
# Update changelog.
# --------------------------------------------------------------------

cd elixir-sources

date=$(date -R)
version=$(git describe --tags | \
  sed -E -e 's/^v//' -e 's/-/~/' -e 's/-/./')

cd ../package-sources

changelog_version=$(dpkg-parsechangelog | \
  sed -n 's/^Version: \(.*\)-[^-]*$/\1/p')

if test "$version" != "$changelog_version"; then
  cat - debian/changelog > debian/changelog.new <<EOF
elixir-lang ($version-1) unstable; urgency=medium

  * New upstream release.

 -- RabbitMQ Team <info@rabbitmq.com>  $date

EOF
  mv debian/changelog.new debian/changelog
fi

# --------------------------------------------------------------------
# Commit changes.
# --------------------------------------------------------------------

git add debian/changelog

git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

cat >../commit-message.txt <<EOF
New upstream release $version
EOF

if ! git diff --cached --quiet; then
  git status
  git commit -F ../commit-message.txt
  # git show --show-signature
fi
