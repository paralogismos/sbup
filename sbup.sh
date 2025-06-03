#! /usr/bin/env sh
# sbup.sh
# A simple script for checking, building, and installing SBCL.
set -e

sbup_version=0.5.0
cwd=$(pwd)

# Get installed version number.
sbcl_installed=$(sbcl --version)
sbcl_installed=${sbcl_installed##*[ ]}

# Get a download url.
sbcl_download="https://sourceforge.net/projects/sbcl/files/latest/download"
sbcl_redirect=$(curl --head --silent --write-out "%{redirect_url}" --output /dev/null $sbcl_download)

# Get latest version number.
sbcl_latest=${sbcl_redirect##*/sbcl/}
sbcl_latest=${sbcl_latest%%/*}

# Construct latest file name.
sbcl_file=${sbcl_redirect##*$sbcl_latest/}
sbcl_file=${sbcl_file%%\?*}

# Construct build directory name.
sbcl_dir=$cwd/sbcl-$sbcl_latest

sbup_diagnostic() {
    printf "\n*** %s ***\n" "$1"
}

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

# Download SBCL to current directory.
download_sbcl() {
    if [ -n $sbcl_redirect ]
    then
        echo "Downloading SBCL $sbcl_latest..."
        curl -L $sbcl_redirect --remote-name
    else
        sbup_diagnostic "Latest version of SBCL not found"
    fi
}

# Extract SBCL build directory into current directory.
unpack_sbcl() {
    if [ -f $cwd/$sbcl_file ]
    then
        echo "Unpacking SBCL $sbcl_latest..."
        tar -xvf $sbcl_file

    else
        sbup_diagnostic "SBCL was not downloaded"
    fi
}

build_sbcl() {
    if [ -d $sbcl_dir ]
    then
        echo "Building SBCL $sbcl_latest..."
        cd $sbcl_dir
        ./make.sh --fancy
    else
        sbup_diagnostic "SBCL was not extracted"
    fi
}

test_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/obj ]
    then
        echo "Running SBCL $sbcl_latest tests..."
        cd $sbcl_dir/tests
        ./run-tests.sh
    else
        sbup_diagnostic "SBCL was not built"
    fi
}

build_sbcl_docs() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Building SBCL $sbcl_latest documentation..."
        cd $sbcl_dir/doc/manual
        make
    else
        sbup_diagnostic "No documentation directory found"
    fi
}

install_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Installing SBCL $sbcl_latest..."
        cd $sbcl_dir
        sudo ./install.sh
    else
        sbup_diagnostic "SBCL was not built"
    fi
}

show_help() {
    printf "sbup version %s\n" $sbup_version
    echo ""
    echo "Usage:"
    echo "sbup [command] {options}"
    echo ""
    echo "Commands:"
    echo "check  ... Check for new version of SBCL"
    echo "get    ... Download latest version of SBCL to current directory"
    echo "build  ... Download latest version of SBCL and build in current directory"
    echo "test   ... Run tests on the latest build of SBCL"
    echo "update ... Download, build, test and install SBCL"
    echo "help   ... Show this help screen"
}

case "$1" in
    check)
        check_sbcl
        ;;
    get)
        download_sbcl
        ;;
    build)
        if ! [ -f $cwd/$sbcl_file ]
        then
            echo $cwd/$sbcl_file
            download_sbcl
        fi
        unpack_sbcl
        build_sbcl
        ;;
    test)
        test_sbcl
        ;;
    update)
        if ! [ -f $cwd/$sbcl_file ]
        then
            download_sbcl
        fi
        if ! [ -d $sbcl_dir ]
        then
            unpack_sbcl
        fi
        build_sbcl
        test_sbcl
        build_sbcl_docs
        install_sbcl
        ;;
    help | "")
        show_help
        ;;
    *)
        show_help
        sbup_diagnostic "Unrecognized command"
        ;;
esac

