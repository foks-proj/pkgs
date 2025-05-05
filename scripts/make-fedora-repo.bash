#!/usr/bin/env bash
set -euo pipefail

KEY=0D05E803516C38D98490757074A9BF0FEB3838CC

if [ ! -f ".top" ]; then 
	echo "must run script from top directory"
	exit 1
fi

sign_rpms() {
    cd rpm-in
    for f in $(ls -1 *.rpm); do
        echo "Signing $f"
        rpm --addsign $f
    done
}

mv_rpm() {
    local from=$1
    local to=$2
    targ_dir=../public/stable/fedora/${to}
    mkdir -p $targ_dir
    for f in $(ls -1 *.${from}.rpm); do
        targ=${targ_dir}/$f
        mv -f $f $targ
    done
}

mv_rpms() {
    cd rpm-in
    mv_rpm "x86_64" "x86_64"
    mv_rpm "aarch64" "aarch64"
    mv_rpm "src" "SRPMS"
}

gen_repo() {
    local arch=$1
    cd public/stable/fedora/${arch}
    rm -rf repodata
    createrepo_c .
    cd repodata
    rm -f repomd.xml.asc
    gpg --default-key ${KEY} --detach-sign --armor repomd.xml
}

gen_repos() {
    (gen_repo x86_64)
    (gen_repo aarch64)
    (gen_repo SRPMS)
}

(sign_rpms)
(mv_rpms)
gen_repos
