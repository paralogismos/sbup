#! /usr/bin/env sh
# clup.sh
# A simple script for checking, building, and installing SBCL.
set -e

clup_version=0.1.0

# Get installed version number.
sbcl_installed=$(sbcl --version)
sbcl_installed=${sbcl_installed##*[ ]}

# Get a download url.
sbcl_download="https://sourceforge.net/projects/sbcl/files/latest/download"
sbcl_redirect=$(curl --head --silent --write-out "%{redirect_url}" --output /dev/null $sbcl_download)

# Get latest version number.
sbcl_latest=${sbcl_redirect##*/sbcl/}
sbcl_latest=${sbcl_latest%%/*}

check_sbcl() {
    if [ "$sbcl_installed" \< "$sbcl_latest" ]
    then
        echo "New version of SBCL available: $sbcl_latest"
    elif [ "$sbcl_latest" = "$sbcl_installed" ]
    then
        echo "Latest version of SBCL already installed: $sbcl_latest"
    else
        echo "Newer version of SBCL already installed: $sbcl_latest < $sbcl_installed"
    fi
}

#download_sbcl() {}
#unpack_sbcl() {}
#build_sbcl() {}
#install_sbcl() {}

if [ "$1" = "check" ]
then
    check_sbcl
elif [ "$sbcl_latest" = "$sbcl_installed" ]
then
    echo "THE Latest version of SBCL already installed: $sbcl_latest"
elif [ "$sbcl_latest" \< "$sbcl_installed" ]
then
    echo "Newer version of SBCL already installed: $sbcl_latest < $sbcl_installed"
else
    echo "Downloading SBCL $sbcl_latest..."
    curl -L $sbcl_redirect --remote-name
    sbcl_file=${sbcl_redirect##*$sbcl_latest/}
    sbcl_file=${sbcl_file%%\?*}
    echo "Unpacking SBCL $sbcl_latest..."
    tar -xvf $sbcl_file
    sbcl_dir=sbcl-$sbcl_latest
    echo "Building SBCL $sbcl_latest..."
    cd $sbcl_dir && ./make.sh --fancy
    echo "Running SBCL $sbcl_latest tests..."
    cd tests && ./run-tests.sh
    echo "Building SBCL $sbcl_latest documentation..."
    cd ../doc/manual && make
    echo "Installing SBCL $sbcl_latest..."
    cd ../.. && sudo ./install.sh
fi

