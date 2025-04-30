#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".top" ]; then 
	echo "must run script from top directory"
	exit 1
fi

cd public/stable/debian

KEY=0D05E803516C38D98490757074A9BF0FEB3838CC

arches=(amd64 arm64 all)
all_arches_string="${arches[*]}"
versions=(bookworm bullseye buster trixie)

link_to() {
  local arch=$1
  for f in $(ls -1 ../../../../pool/main/f/*_${arch}.deb); do
    ln -sf $f
  done
}

do_version_arch() {
  local version=$1
  local arch=$2
  local dir="dists/${version}/main/binary-${arch}"
  mkdir -p "${dir}"

  (cd ${dir} && link_to "${arch}")

  # regenerate Packages
  apt-ftparchive \
    -o APT::FTPArchive::Index::Compression::gzip=false \
    -o APT::FTPArchive::Release::Codename="${version}" \
    -o APT::FTPArchive::Release::Origin="foks" \
    -o APT::FTPArchive::Release::Label="foks" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Architectures="${all_arches_string}" \
    -o APT::FTPArchive::Release::Description="FOKS packages (see https://foks.pub)" \
    packages "dists/${version}/main/binary-${arch}" \
    > "dists/${version}/main/binary-${arch}/Packages"

  gzip -9n -c \
    "dists/${version}/main/binary-${arch}/Packages" \
    > "dists/${version}/main/binary-${arch}/Packages.gz"
}

do_version() {
  local version=$1

  for arch in "${arches[@]}"; do
    do_version_arch "${version}" "${arch}"
  done

  apt-ftparchive \
    -o APT::FTPArchive::Index::Compression::gzip=false \
    -o APT::FTPArchive::Release::Codename="${version}" \
    -o APT::FTPArchive::Release::Origin="foks" \
    -o APT::FTPArchive::Release::Label="foks" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Architectures="${all_arches_string}" \
    -o APT::FTPArchive::Release::Description="FOKS packages (see https://foks.pub)" \
    release "dists/${version}" \
    > "dists/${version}/Release"

  inrel=dists/${version}/InRelease
  [ ! -f "${inrel}" ] || rm "${inrel}"
  gpg --default-key "${KEY}" \
    --clearsign -o "${inrel}" \
    "dists/${version}/Release"

  relgpg=dists/${version}/Release.gpg
  [ ! -f "${relgpg}" ] || rm "${relgpg}"
  gpg --default-key "${KEY}" \
    --output "${relgpg}" \
    --detach-sign "dists/${version}/Release"

  cat <<EOF > ${version}.foks-keyring.list
# Foks packages for debian ${version}
deb [signed-by=/usr/share/keyrings/foks-archive-keyring.gpg] https://pkgs.foks.pub/stable/debian ${version} main
EOF
  ln -sf ../../keyrings/debian/v1.0.0.gpg ${version}.noarmor.gpg
}

for version in "${versions[@]}"; do
  do_version "${version}"
done
