#! /usr/bin/env sh
# sbup.sh
# A simple script for checking, building, and installing SBCL.
set -e

sbup_version=0.8.0
cwd=$(pwd)

# Check for installed SBCL
if ! type sbcl ; then
    echo "SBCL is not currently installed: no update possible"
    exit 1
fi

# Get installed version number.
sbcl_installed=$(sbcl --version)
sbcl_installed=${sbcl_installed##*[ ]}

# Get a download url.
sbcl_download="https://sourceforge.net/projects/sbcl/files/latest/download"
if type curl > /dev/null ; then
    sbcl_redirect=$(curl --head --silent --write-out "%{redirect_url}" --output /dev/null $sbcl_download)
elif type wget > /dev/null ; then
    sbcl_redirect=$(wget --spider --force-html $sbcl_download 2>&1 | grep -m 1 Location)
else
    type curl
    type wget
    echo ${0##*/}": Either \`curl\` or \`wget\` must be installed"
    exit 1
fi

# Get latest version number.
sbcl_latest=${sbcl_redirect##*/sbcl/}
sbcl_latest=${sbcl_latest%%/*}

# Construct latest file name.
sbcl_file=${sbcl_redirect##*$sbcl_latest/}
sbcl_file=${sbcl_file%%\?*}

# Construct build directory name.
sbcl_dir=$cwd/sbcl-$sbcl_latest

script_fail() {
    printf "*** %s : %s ***\n" "$1" "$2" >&2
    usage
    exit 2
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
        script_fail "Latest version of SBCL not found"
    fi
}

# Extract SBCL build directory into current directory.
unpack_sbcl() {
    if [ -f $cwd/$sbcl_file ]
    then
        echo "Unpacking SBCL $sbcl_latest..."
        tar -xvf $sbcl_file

    else
        script_fail "SBCL was not downloaded"
    fi
}

build_sbcl() {
    if [ -d $sbcl_dir ]
    then
        echo "Building SBCL $sbcl_latest..."
        cd $sbcl_dir
        sh make.sh $@
    else
        script_fail "SBCL was not extracted"
    fi
}

test_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/obj ]
    then
        echo "Running SBCL $sbcl_latest tests..."
        cd $sbcl_dir/tests
        sh run-tests.sh
    else
        script_fail "SBCL was not built"
    fi
}

build_sbcl_docs() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Building SBCL $sbcl_latest documentation..."
        cd $sbcl_dir/doc/manual
        make
    else
        script_fail "No documentation directory found"
    fi
}

install_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Installing SBCL $sbcl_latest..."
        cd $sbcl_dir
        export INSTALL_ROOT="$1"
        $2 sh install.sh
        unset INSTALL_ROOT
    else
        script_fail "SBCL was not built"
    fi
}

usage() {
    printf "sbup version %s\n" $sbup_version
    echo ""
    echo "Usage:"
    echo "sbup [command] {Sbup options} [-- {SBCL options}]"
    echo ""
    echo "Commands:"
    echo "check  ... Check for new version of SBCL"
    echo "get    ... Download latest version of SBCL to current directory"
    echo "build  ... Download latest version of SBCL and build in current directory"
    echo "test   ... Run tests on the latest build of SBCL"
    echo "update ... Download, build, test and install SBCL"
    echo "help   ... Show this help screen"
    echo ""
    echo "Options:"
    echo "-i | --install_root ... Configure SBCL \`INSTALL_ROOT\`"
    echo "--nodocs            ... Disable building of documentation"
    echo "                        Used with \`build\` and \`update\`"
    echo "--noinstall         ... Disable final installation"
    echo "                        Used with \`update\`"
    echo "--notest            ... Disable running of tests"
    echo "                        Used with \`update\`"
    echo "-u | --user         ... Enable user installation (without \`sudo\`)"
}

# Parse script commands.
command=
modifier=

if ! [ -z ${1%%-*} ] ; then
    command="$1"
    shift
fi
if ! [ -z ${1%%-*} ] ; then
    modifier="$1"
    shift
fi

# Parse script options.
install_root=  # `--install_root` configures SBCL `INSTALL_ROOT`
nodocs=        # `--nodocs` disables documentation phase for `build` and `update`
noinstall=     # `--noinstall` disables `update` installation phase
notest=        # `--notest` disables `update` testing phase
user=false     # `--user` signals a user installation (without `sudo`)

# Check long options for required arguments.
require_arg() {
    if [ -z "$OPTARG" ] ; then
        script_fail "Argument required" "--$OPT"
    fi
}

while getopts i:u-: OPT
do
    if [ $OPT = "-" ]  ; then
        OPT=${OPTARG%%=*}     # get long option
        OPTARG=${OPTARG#$OPT}  # get long option argument
        OPTARG=${OPTARG#=}
    fi
    case "$OPT" in
        i | install_root )
            require_arg ; install_root="$(cd $OPTARG ; pwd)" ;;
        nodocs )
            nodocs=true ;;
        noinstall )
            noinstall=true ;;
        notest )
            notest=true ;;
        u | user )
            user=true ;;
        \?)
            usage ; exit 2 ;;  # short option fail reported by `getopts`
        *)
            script_fail "Unrecognized option" "--$OPT" ;;  # long option fail
    esac
done

# Form `make.sh` options.
shift $((OPTIND - 1))
make_suffix="$(echo $@)"

# Form `make install` mode prefix.
install_mode=
if ! $user  ; then install_mode=sudo ; fi

# Handle commands.
case "$command" in
    check)
        check_sbcl
        ;;
    get)
        download_sbcl
        ;;
    build)
        if ! [ -f $cwd/$sbcl_file ] ; then
            echo $cwd/$sbcl_file
            download_sbcl
        fi
        unpack_sbcl
        build_sbcl $make_suffix
        if [ -z "$nodocs" ] ; then
            build_sbcl_docs
        fi
        ;;
    test)
        test_sbcl
        ;;
    update)
        if ! [ -f $cwd/$sbcl_file ] ; then
            download_sbcl
        fi
        if ! [ -d $sbcl_dir ] ; then
            unpack_sbcl
        fi
        build_sbcl $make_suffix
        if [ -z "$notest" ] ; then
            test_sbcl
        fi
        if [ -z "$nodocs" ] ; then
            build_sbcl_docs
        fi
        if [ -z "$noinstall" ] ; then
            install_sbcl $install_root $install_mode
        fi
        ;;
    help | "")
        usage
        ;;
    *)
        script_fail "Unrecognized command" "$command"
        ;;
esac
