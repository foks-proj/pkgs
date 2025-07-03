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

hashup() {
  local file=$1
  local -n out=$2
  filesz=$(stat -f %z -L "${file}")
  sha1=$(shasum -a 1 "${file}" | cut -d ' ' -f 1)
  sha256=$(shasum -a 256 "${file}" | cut -d ' ' -f 1)
  sha512=$(shasum -a 512 "${file}" | cut -d ' ' -f 1)
  md5=$(md5 -q "${file}")
  out=(${filesz} ${md5} ${sha1} ${sha256} ${sha512})
}

my_apt_ftparchive_one() {
  local file=$1
  local dir=$2
  control=${file}.control
  ar p ${file} control.tar.xz | tar -xO - control > $control
  declare -a hashes
  hashup "${file}" hashes

  out=${file}.desc
  head -5 < $control > $out
  cat <<EOF >>$out
Filename: ${dir}/${file}
Size: ${hashes[0]}
MD5sum: ${hashes[1]}
SHA1: ${hashes[2]}
SHA256: ${hashes[3]}
SHA512: ${hashes[4]}
EOF
  tail -n +6 < $control >> $out
  echo >> $out
  rm $control
}

my_apt_ftparchive_packages() {(
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
  my_apt_ftparchive_packages "${dir}" > ${dir}/Packages

  gzip -9n -c "${dir}/Packages" > "${dir}/Packages.gz" 
}

my_apt_ftparchive_release() {
  local dir=$1
  local version=$2
  cd "${dir}"
  out=Release
  date=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
  cat <<EOF >hdr
Archtectures: ${all_arches_string}
Codename: ${version}
Components: main
Date: ${date}
Description: FOKS packages (see https://foks.pub)
Label: foks
Origin: foks
EOF
  declare -a metadata_hashes 
  hashup hdr metadata_hashes

  echo "MD5Sum:" > md5
  echo -e " ${metadata_hashes[1]}\t${metadata_hashes[0]} ${out}" >> md5
  echo "SHA1:" > sha1
  echo -e " ${metadata_hashes[2]}\t${metadata_hashes[0]} ${out}" >> sha1
  echo "SHA256:" > sha256
  echo -e " ${metadata_hashes[3]}\t${metadata_hashes[0]} ${out}" >> sha256
  echo "SHA512:" > sha512
  echo -e " ${metadata_hashes[4]}\t${metadata_hashes[0]} ${out}" >> sha512

  find . -type f -regex '.*/Packages\(\\.gz\)\?' -print0 | while IFS= read -r -d '' f; do
    declare -a hashes
    hashup "${f}" hashes
    echo -e " ${hashes[1]}\t${hashes[0]} ${f}" >> md5
    echo -e " ${hashes[2]}\t${hashes[0]} ${f}" >> sha1
    echo -e " ${hashes[3]}\t${hashes[0]} ${f}" >> sha256
    echo -e " ${hashes[4]}\t${hashes[0]} ${f}" >> sha512
  done

  cat hdr md5 sha1 sha256 sha512 > "${out}"
}

do_version_release() {(
  local version=$1
  local dir="dists/${version}"
  mkdir -p "${dir}"
  my_apt_ftparchive_release "${dir}" "${version}"
)}

do_version() {
  local os=$1
  local version=$2

  for arch in "${arches[@]}"; do
    do_version_arch "${version}" "${arch}"
  done

  do_version_release "${version}"

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
