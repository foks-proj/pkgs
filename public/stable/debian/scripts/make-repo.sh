#!/usr/bin/env bash
set -euo pipefail

SITE=.
KEY=0D05E803516C38D98490757074A9BF0FEB3838CC
# regenerate Packages
apt-ftparchive -o APT::FTPArchive::Index::Compression::gzip=false \
    packages "${SITE}/dists/stable/main/binary-amd64" \
  > "${SITE}/dists/stable/main/binary-amd64/Packages"

gzip -9n -c \
  "${SITE}/dists/stable/main/binary-amd64/Packages" \
  > "${SITE}/dists/stable/main/binary-amd64/Packages.gz"

# regenerate Release
apt-ftparchive release "${SITE}/dists/stable" \
  > "${SITE}/dists/stable/Release"

# sign Release → InRelease & Release.gpg
gpg --default-key "${KEY}" \
    --clearsign -o "${SITE}/dists/stable/InRelease" \
    "${SITE}/dists/stable/Release"

gpg --default-key "${KEY}" \
    --output "${SITE}/dists/stable/Release.gpg" \
    --detach-sign "${SITE}/dists/stable/Release"

