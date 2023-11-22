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
  ca-certificates \
  dpkg-dev \
  git \
  gpg

# --------------------------------------------------------------------
# Update changelog.
# --------------------------------------------------------------------

cd erlang-sources

date=$(date -R)
version=$(git describe --tags --abbrev=10)
case "$version" in
  OTP-*)
    version=$(echo "$version" | \
      sed -E \
      -e 's/^OTP-//' \
      -e 's/-/~/' \
      -e 's/-/./')
    ;;
  OTP_*)
    version=$(echo "$version" | \
      sed -E \
      -e 's/OTP_R([1-9]+)B0*([1-9]+)($|-([0-9]+))/\1.b.\2\3/' \
      -e 's/-/./')
    ;;
  *)
    exit 1
    ;;
esac

if test "$(git rev-parse HEAD)" = "$(git rev-parse master)"; then
  # If we are on the `master` branch of Erlang, the last tag doesn't
  # match the future version of Erlang. Let's construct the version from
  # the `OTP_VERSION` file.
  future_version=$(cat OTP_VERSION)
  future_version=${future_version%-*}
  version=$(echo "$version" | sed -E 's/([^~]+)/'"$future_version"'/')
fi

cd ../package-sources

changelog_version=$(dpkg-parsechangelog | \
  sed -n 's/^Version: [0-9]:\(.*\)-[^-]*$/\1/p')

if test "$version" != "$changelog_version"; then
  cat - debian/changelog > debian/changelog.new <<EOF
erlang (1:$version-1) unstable; urgency=medium

  * New upstream release.

 -- RabbitMQ Team <info@rabbitmq.com>  $date

EOF
  mv debian/changelog.new debian/changelog
fi

# --------------------------------------------------------------------
# Commit changes.
# --------------------------------------------------------------------

git add debian/changelog

# The author name & email are set by Concourse in the environment. However, this
# isn't enough to please Git: it requires us to define global defaults.
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
