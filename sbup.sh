#! /usr/bin/env sh
# sbup.sh
# A simple script for checking, building, and installing SBCL.
set -e
#set -x

sbup_version=0.10.0
sbup_dir=$HOME/.sbup

if ! [ -d "$sbup_dir" ] ; then mkdir "$sbup_dir" ; fi
reset_dir=$(pwd)
cd "$sbup_dir"

# Detect downloader.
downloader=
if type curl > /dev/null ; then
    downloader=curl
elif type wget > /dev/null ; then
    downloader=wget
else
    type curl
    type wget
    echo ${0##*/}": Either \`curl\` or \`wget\` must be installed"
    cd "$reset_dir"
    exit 1
fi

match_version='[[:digit:]]+.[[:digit:]]+.[[:digit:]]+'

usage() {
    printf "sbup version %s\n" $sbup_version
    echo ""
    echo "Usage:"
    echo "sbup [command] {Sbup options} [-- {SBCL options}]"
    echo ""
    echo "Commands:"
    echo "check  ... Check for new version of SBCL"
    echo "list   ... Show available SBCL versions"
    echo "           \`list\`, \`list recent\` lists the most recent versions"
    echo "           \`list all\` lists all available versions"
    echo "           \`list <N>\` lists the most recent <N> versions"
    echo "           \`list downloads\`, \`list downloaded\`, \`list dl\`"
    echo "               lists all downloaded SBCL tarballs"
    echo "           \`list built\`, \`list b\` lists all available SBCL builds"
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

script_fail() {
    printf "*** %s : %s ***\n" "$1" "$2" >&2
    usage
    cd "$reset_dir"
    exit 2
}

# Check for installed SBCL
if ! type sbcl ; then
    echo "SBCL is not currently installed: no update possible"
    cd "$reset_dir"
    exit 1
fi

# Get installed version number.
cur_ver=$(sbcl --version)
cur_ver=${cur_ver##*[ ]}

# Get downloaded version numbers.
sbcl_downloaded=$(find "$sbup_dir" -maxdepth 1 -type f |
                      grep -E "sbcl-$match_version-source" |
                      grep -Eo $match_version |
                      sort -t. -k 1,1nr -k 2,2nr -k 3,3nr -k 4,4nr)

sbcl_latest_downloaded=$(echo $sbcl_downloaded | awk '{print $1}')

# Get built version numbers.
sbcl_built=$(find "$sbup_dir" -maxdepth 1 -type d |
                 grep "sbcl" |
                 grep -Eo $match_version |
                 sort -t. -k 1,1nr -k 2,2nr -k 3,3nr -k 4,4nr)

sbcl_latest_built=$(echo $sbcl_built | awk '{print $1}')

# Get a download url.
sbcl_files_dl="https://sourceforge.net/projects/sbcl/files/sbcl"
sbcl_version_line='<th scope="row" headers="files_name_h"><a href="/projects/sbcl/files/sbcl/'
sbcl_available=
case "$downloader" in
    curl )
        sbcl_available=$(curl -L --silent $sbcl_files_dl \
                             | grep "$sbcl_version_line" \
                             | grep -Eo $match_version)
        ;;
    wget )
        sbcl_available=$(wget -q -O- $sbcl_files_dl \
                             | grep "$sbcl_version_line" \
                             | grep -Eo $match_version)
        ;;
    * )
        script_fail "Unrecognized downloader" "$downloader"  # should never happen
        ;;
esac

# Get latest version number.
sbcl_latest_available=$(echo $sbcl_available | awk '{print $1}')

# Construct latest file name.
sbcl_file="sbcl-$sbcl_latest_available-source.tar.bz2"

# Construct build directory name.
sbcl_dir=$sbup_dir/sbcl-$sbcl_latest_available

check_sbcl() {
    if [ "$cur_ver" = "$sbcl_latest_available" ]
    then
        echo "Already using most recent SBCL: $cur_ver"
    elif [ "$sbcl_latest_built" = "$sbcl_latest_available" ]
    then
        echo "Most recent SBCL already built: $sbcl_latest_built"
    elif [ "$sbcl_latest_downloaded" = "$sbcl_latest_available" ]
    then
        echo "Most recent SBCL already downloaded: $sbcl_latest_downloaded"
    else
        echo "New version of SBCL available: $sbcl_latest_available"
    fi
}

list_available() {
    sbcl_show_count=
    if [ $1 = "recent" ] ;
    then
        sbcl_show_count=10 ;
    elif ! [ $1 = "all" ] ;
    then
        sbcl_show_count=$1 ;
    fi
    for sbcl_version in $sbcl_available ; do
        if [ $1 = "all" ] ;
        then
            echo $sbcl_version ; continue
        elif [ $sbcl_show_count -eq 0 ] ;
        then
            break
        else
            echo $sbcl_version ; sbcl_show_count=$((sbcl_show_count-1))
        fi
    done
}

# Download SBCL to current directory.
download_sbcl() {
    sbcl_downloading="$sbcl_files_dl/$1/sbcl-$1-source.tar.bz2"
    echo "Downloading SBCL $sbcl_downloading..."
    case "$downloader" in
        curl )
            curl -L "$sbcl_downloading" --remote-name ;;
        wget )
            wget -q --show-progress "$sbcl_downloading" ;;
        *)
            script_fail "Unrecognized downloader" "$downloader" ;;  # should never happen
    esac
}

# Extract SBCL build directory into current directory.
unpack_sbcl() {
    if [ -f $sbup_dir/$sbcl_file ]
    then
        echo "Unpacking SBCL $sbcl_latest_available..."
        tar -xvf $sbcl_file
    else
        script_fail "SBCL was not downloaded"
    fi
}

build_sbcl() {
    if [ -d $sbcl_dir ]
    then
        echo "Building SBCL $sbcl_latest_available..."
        cd $sbcl_dir
        sh make.sh $@
    else
        script_fail "SBCL was not extracted"
    fi
}

test_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/obj ]
    then
        echo "Running SBCL $sbcl_latest_available tests..."
        cd $sbcl_dir/tests
        sh run-tests.sh
    else
        script_fail "SBCL was not built"
    fi
}

build_sbcl_docs() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Building SBCL $sbcl_latest_available documentation..."
        cd $sbcl_dir/doc/manual
        make
    else
        script_fail "No documentation directory found"
    fi
}

install_sbcl() {
    if [ -d $sbcl_dir ] && [ -d $sbcl_dir/doc ]
    then
        echo "Installing SBCL $sbcl_latest_available..."
        cd $sbcl_dir
        export INSTALL_ROOT="$1"
        $2 sh install.sh
        unset INSTALL_ROOT
    else
        script_fail "SBCL was not built"
    fi
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
            usage ; cd "$reset_dir"
            exit 2 ;;  # short option fail reported by `getopts`
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
    check )
        check_sbcl
        ;;
    list )
        case "$modifier" in
            all | recent )
                list_available $modifier
                ;;
            "" )
                list_available recent
                ;;
            dl | downloads | downloaded)
                printf "available SBCL tarballs:\n"
                for dl in $sbcl_downloaded ; do
                    if [ "$dl" = "$cur_ver" ] ; then printf "> %s <\n" "$dl"
                    else printf "  %s\n" "$dl"
                    fi
                done
                ;;
            b | built)
                printf "available SBCL builds:\n"
                for build in $sbcl_built ; do
                    if [ "$build" = "$cur_ver" ] ; then printf "> %s <\n" "$build"
                    else printf "  %s\n" "$build"
                    fi
                done
                ;;
            *[!0123456789]* )
                script_fail "Unrecognized command" "$command $modifier"
                ;;
            * )
                list_available $modifier
                ;;
        esac
        ;;
    get )
        case "$modifier" in
            "" | latest )
                download_sbcl "$sbcl_latest_available"
                ;;
            * )
                if ! $(echo "$modifier" | grep -E ^$match_version > /dev/null) ; then
                    script_fail "Not a version number" "get $modifer"
                elif ! $(echo "$sbcl_available" | grep "$modifier" > /dev/null) ; then
                    script_fail "Version not available" "$modifier"
                fi
                download_sbcl "$modifier"
                ;;
        esac
        ;;
    build )
        if ! [ -f $sbup_dir/$sbcl_file ] ; then
            echo $sbup_dir/$sbcl_file
            download_sbcl
        fi
        unpack_sbcl
        build_sbcl $make_suffix
        if [ -z "$nodocs" ] ; then
            build_sbcl_docs
        fi
        ;;
    test )
        test_sbcl
        ;;
    update )
        if ! [ -f $sbup_dir/$sbcl_file ] ; then
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
    help | "" )
        usage
        ;;
    * )
        script_fail "Unrecognized command" "$command"
        ;;
esac

cd "$reset_dir"
