#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".top" ]; then 
	echo "must run script from top directory"
	exit 1
fi

KEY=0D05E803516C38D98490757074A9BF0FEB3838CC

arches=(amd64 arm64 all)
all_arches_string="${arches[*]}"

link_to() {
  local arch=$1
  for f in $(ls -1 ../../../../pool/main/f/*_${arch}.deb); do
    ln -sf $f
  done
}

my_apt_ftparchive_one() {
  local file=$1
  local dir=$2
  control=${file}.control
  ar p ${file} control.tar.xz | tar -xO - control > $control
  filesz=$(stat -f %z -L "${file}")
  sha1=$(shasum -a 1 "${file}" | cut -d ' ' -f 1)
  sha256=$(shasum -a 256 "${file}" | cut -d ' ' -f 1)
  sha512=$(shasum -a 512 "${file}" | cut -d ' ' -f 1)
  md5=$(md5 -q "${file}")

  out=${file}.desc
  head -5 < $control > $out
  cat <<EOF >>$out
Filename: ${dir}/${file}
Size: ${filesz}
MD5sum: ${md5}
SHA1: ${sha1}
SHA256: ${sha256}
SHA512: ${sha512}
EOF
  tail -n +6 < $control >> $out
  echo >> $out
  rm $control
}

my_apt_ftparchive() {(
  local dir=$1
  cd "${dir}"
  files=$(ls -1 *.deb | sort -V)
  for f in ${files}; do
    my_apt_ftparchive_one $f $dir
  done
  ls -1 *.deb.desc | sort -V | xargs cat
  rm *.deb.desc 
)}

do_version_arch() {
  local version=$1
  local arch=$2
  local dir="dists/${version}/main/binary-${arch}"
  mkdir -p "${dir}"

  (cd ${dir} && link_to "${arch}")

  # regenerate Packages
  my_apt_ftparchive "${dir}" > ${dir}/Packages

  gzip -9n -c "${dir}/Packages" > "${dir}/Packages.gz" 
}

do_version() {
  local os=$1
  local version=$2

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
# Foks packages for ${os} ${version}
deb [signed-by=/usr/share/keyrings/foks-archive-keyring.gpg] https://pkgs.foks.pub/stable/${os} ${version} main
EOF
  ln -sf ../../keyrings/debian/v1.0.0.gpg ${version}.noarmor.gpg
}

do_os() {
  local os=$1
  shift
  local versions=( "$@" )
  dir=public/stable/$os
  mkdir -p ${dir}
  cd ${dir}

  rm -rf ./pool

  # the apt-ftparchive tool is **fanatical** about the directory structure being just like
  # so, without any symlinks. so copy it into place temporarily, and then below,
  # delete the copy and symlink to the real one. our serving solution (cloudflare)
  # seems to be more reasonable about symlinks and hides the structure from the remote user.
  cp -r ../../pool pool

  for version in "${versions[@]}"; do
    do_version "${os}" "${version}"
  done

  rm -rf ./pool
  ln -sf ../../pool
}

(do_os debian \
	bookworm bullseye buster trixie)

(do_os ubuntu \
	plucky oracular noble jammy focal bionic xenial)
