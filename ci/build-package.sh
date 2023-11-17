#!/bin/sh
# vim:sw=2:et:

set -ex

INITIAL_DIRECTORY=$PWD

if test -f /etc/debian_version; then
  dist_version=debian-$(cat /etc/debian_version)
fi

# --------------------------------------------------------------------
# Install package building tools.
# --------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y tzdata

echo "Europe/London" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  devscripts \
  equivs \
  git \
  gnupg

apt-get install -y --no-install-recommends git-buildpackage

# --------------------------------------------------------------------
# Setup PGP signing key.
# --------------------------------------------------------------------

gpg -K "$SIGNING_KEY_ID"

# --------------------------------------------------------------------
# Prepare package.
# --------------------------------------------------------------------

cd erlang-sources

cp -a ../package-sources/debian .

branch=erlang-debian-package-by-rabbitmq
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

tag=upstream-tag-for-debian-package

git rev-parse "$tag" -- >/dev/null 2>&1 || git tag "$tag"
git checkout -b "$branch"

# Remove non-free documentation.
for fn in $(find lib/*/doc -name standard -or -name archive); do
  rm -rf "$fn"
done

# --------------------------------------------------------------------
# Configure git-buildpackage.
# --------------------------------------------------------------------

cat > ~/.gbp.conf <<EOF
[DEFAULT]
upstream-tag = $tag
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

mk-build-deps -i \
  -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y'
rm -f erlang-build-deps*

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
