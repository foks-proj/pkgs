#!/bin/sh

install() {

	version=0.0.20


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

        arch=$(uname -m)
        if [ "$arch" = "x86_64" ]; then
                arch="amd64"
        elif [ "$arch" = "aarch64" ]; then
                arch="arm64"
        else
                echo "Unsupported architecture: $arch"
                echo "This script only supports x86_64 (amd64) and aarch64 (arm64)."
                exit 1
        fi
        echo "Detected architecture: $arch"

	# Step 3: work out if we can run privileged commands, and if so,
	# how.
	CAN_ROOT=
	SUDO=
	IS_ROOT=0
	if [ "$(id -u)" = 0 ]; then
		CAN_ROOT=1
		SUDO=""
		IS_ROOT=1
	elif type sudo >/dev/null; then
		CAN_ROOT=1
		SUDO="sudo"
	elif type doas >/dev/null; then
		CAN_ROOT=1
		SUDO="doas"
	fi
	if [ "$CAN_ROOT" != "1" ]; then
		echo "This installer needs to run commands as root."
		echo "We tried looking for 'sudo' and 'doas', but couldn't find them."
		echo "Either re-run this script as root, or set up sudo/doas."
		exit 1
	fi

        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        cd "$tmp" 
        echo "Downloading foks version $version..."

        $CURL https://github.com/foks-proj/go-foks/releases/download/v${version}/foks-${version}.musl.linux.${arch}.gz > foks.gz
        if [ $? -ne 0 ]; then
                echo "Failed to download foks. Please check your internet connection or the URL."
                exit 1
        fi
        echo "Download complete. Extracting foks..."
        gunzip foks.gz
        if [ $? -ne 0 ]; then
                echo "Failed to extract foks. Please check if gunzip is installed."
                exit 1
        fi
        install_dir=/usr/bin
        echo "Moving foks to ${install_dir}..."
        $SUDO mv -f foks ${install_dir}/foks
        if [ $? -ne 0 ]; then
                echo "Failed to move foks to /usr/local/bin. Please check your permissions."
                exit 1
        fi
        echo "Setting executable permissions for foks..."
        sudo chmod +x ${install_dir}/foks
        if [ $? -ne 0 ]; then
                echo "Failed to set executable permissions for foks. Please check your permissions."
                exit 1
        fi
        echo "foks installation complete. You can now run foks from anywhere."
        echo "To verify the installation, run: foks --version"
}

run
