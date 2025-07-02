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

fsz() {
  local file=$1
  stat -f %z -L "${file}"
}
fsha1() {
  local file=$1
  shasum -a 1 "${file}" | cut -d ' ' -f 1
}
fsha256() {
  local file=$1
  shasum -a 256 "${file}" | cut -d ' ' -f 1
}
fsha512() {
  local file=$1
  shasum -a 512 "${file}" | cut -d ' ' -f 1
}
fmd5() {
  local file=$1
  md5 -q "${file}"
}

printsz() {
  printf "%16d" "$1"
}

my_apt_ftparchive_one() {
  local file=$1
  local dir=$2
  control=${file}.control
  ar p ${file} control.tar.xz | tar -xO - control > $control

  out=${file}.desc
  head -5 < $control > $out
  cat <<EOF >>$out
Filename: ${dir}/${file}
Size: $(fsz ${file})
MD5sum: $(fmd5 ${file})
SHA1: $(fsha1 ${file})
SHA256: $(fsha256 ${file})
SHA512: $(fsha512 ${file})
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
Architectures: ${all_arches_string}
Codename: ${version}
Components: main
Date: ${date}
Description: FOKS packages (see https://foks.pub)
Label: foks
Origin: foks
EOF

  sz=$(fsz hdr)
  echo "MD5Sum:" > md5
  echo " $(fmd5 hdr)$(printsz ${sz}) ${out}" >> md5
  echo "SHA1:" > sha1
  echo -e " $(fsha1 hdr)$(printsz ${sz}) ${out}" >> sha1
  echo "SHA256:" > sha256
  echo -e " $(fsha256 hdr)$(printsz ${sz}) ${out}" >> sha256
  echo "SHA512:" > sha512
  echo -e " $(fsha512 hdr)$(printsz ${sz}) ${out}" >> sha512

  find . -type f -regex '.*/Packages.*' -print0 | while IFS= read -r -d '' f; do
    sz=$(fsz "${f}")
    p=$(echo ${f} | sed 's#^./##')
    echo -e " $(fmd5 "${f}")$(printsz ${sz}) ${p}" >> md5
    echo -e " $(fsha1 "${f}")$(printsz ${sz}) ${p}" >> sha1
    echo -e " $(fsha256 "${f}")$(printsz ${sz}) ${p}" >> sha256
    echo -e " $(fsha512 "${f}")$(printsz ${sz}) ${p}" >> sha512
  done

  cat hdr md5 sha1 sha256 sha512 > "${out}"
  rm hdr md5 sha1 sha256 sha512
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
    echo "Generating ${os} ${version} ${arch}...."
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

  for version in "${versions[@]}"; do
    do_version "${os}" "${version}"
  done
}

(do_os debian \
	bookworm bullseye buster trixie)

(do_os ubuntu \
	plucky oracular noble jammy focal bionic xenial)
