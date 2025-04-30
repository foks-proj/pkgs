#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".top" ]; then 
	echo "must run script from top directory"
	exit 1
fi

cd public/stable/debian

SITE=.

KEY=0D05E803516C38D98490757074A9BF0FEB3838CC

for arch in {amd64,arm64,all}; do
  # regenerate Packages
  apt-ftparchive -o APT::FTPArchive::Index::Compression::gzip=false \
    packages "${SITE}/dists/stable/main/binary-${arch}" \
    > "${SITE}/dists/stable/main/binary-${arch}/Packages"

  gzip -9n -c \
    "${SITE}/dists/stable/main/binary-${arch}/Packages" \
    > "${SITE}/dists/stable/main/binary-${arch}/Packages.gz"

done


# regenerate Release
apt-ftparchive release "${SITE}/dists/stable" \
  > "${SITE}/dists/stable/Release"

# sign Release → InRelease & Release.gpg
rm ${SITE}/dists/stable/InRelease
gpg --default-key "${KEY}" \
    --clearsign -o "${SITE}/dists/stable/InRelease" \
    "${SITE}/dists/stable/Release"

rm ${SITE}/dists/stable/Release.gpg
gpg --default-key "${KEY}" \
    --output "${SITE}/dists/stable/Release.gpg" \
    --detach-sign "${SITE}/dists/stable/Release"

