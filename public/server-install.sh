#!/bin/sh

set -eu


main() {

    uarch=$(uname -m)
    arch=""
    case "$uarch" in
        x86_64)   arch="amd64" ;;
        aarch64)  arch="arm64" ;;
        *)        
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

	# Ideally we want to use curl, but on some installs we
	# only have wget. Detect and use what's available.
	CURL=
	if type curl >/dev/null; then
		CURL="curl -fsSL"
	elif type wget >/dev/null; then
		CURL="wget -q -O-"
	fi
	if [ -z "$CURL" ]; then
		echo "The installer needs either curl or wget to download files."
		echo "Please install either curl or wget to proceed."
		exit 1
	fi

    latest=$(
        $CURL https://pkgs.foks.pub/stable/changelog.yml | \
            grep version | head -1 | cut -d: -f2
    )

    $CURL https://github.com/foks-proj/go-foks/releases/download/${latest}/foks-tool.linux.${arch}.gz | \
        gunzip -c > ./foks-tool

    chmod +x ./foks-tool
    ./foks-tool standup "$@"

}