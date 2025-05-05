#!/bin/sh
# Copyright (c) 2025 ne43, Inc.
# Licensed under the MIT License. See LICENSE in the project root for details.

# This script builds a debian package for foks via docker, so should work on most platforms.

set -euo pipefail


usage() {
    echo "Usage: $0"
    exit 1
}

if [ $# -ne 0 ]; then
   usage
fi

if [ ! -f ".top" ]; then
    echo "This script must be run from the root of the pkgs repository."
    exit 1
fi

vversion=$(git tag --list | grep -E '^v[0-9]+\.' | sort -V | tail -1)
version=$(echo $vversion | sed 's/^v//')

if [ -z "$version" ]; then
    echo "No version found. Please tag the commit with a version."
    exit 1
fi

echo "Building foks-archive-keyring version $version"

make_control() {
    cat <<EOF > build/debian.control-${version}
Package: foks-archive-keyring
Version: ${version}
Section: misc
Priority: optional
Architecture: all
Maintainer: Maxwell Krohn <max@ne43.com>
Description: Keyring for the foks APT repository
 This package provides the public key used to verify packages
 in the fos apt repository.  It installs the key to
 /usr/share/keyrings/foks-archive-keyring.gpg
EOF
}

make_copyright() {
    cat <<EOF > build/debian.copyright
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: foks-archive-keyring
Source: https://github.com/foks-proj/pkgs

Files: *
Copyright: 2025 Maxwell Krohn <max@ne43.com>
License: MIT

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
}

make_changelog() {
    cl_vers=$(grep -- '- version' changelog.yml  | head -n1 |  awk -F: ' { print $2 }' | xargs)
    if [ "$cl_vers" != "$version" ]; then
        echo "Version in changelog.yml ($cl_vers) does not match version ($version)"
        exit 1
    fi
    go tool github.com/foks-proj/go-tools/changelog-deb < changelog.yml | gzip -n9c > build/debian.changelog-${version}.gz
}

build_deb() {
    name=foks-archive-keyring-deb-${version}
    tmp=tmp-${name}
    docker build \
        -f dockerfiles/deb-pkg.dev \
        --build-arg VERSION=${version} \
        -t ${name} \
        .
    docker create  \
        --name=${tmp} \
        ${name}
    docker cp ${tmp}:/pkg/foks-archive-keyring_${version}_all.deb build/
    docker rm ${tmp}

    echo "Debian package foks-archive-keyring_${version}_all.deb created in build/"
}

mkdir -p build

make_copyright
make_control
make_changelog
build_deb