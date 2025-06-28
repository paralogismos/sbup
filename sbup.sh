#! /usr/bin/env sh
# sbup.sh
# A simple script for checking, building, and installing SBCL.
set -e
#set -x

# Global build parameters.
sbup_version=0.10.0
sbup_dir=$HOME/.sbup
sbcl_show_count=
downloading_url=
building_version=
building_file=
building_dir=

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
    printf "%s\n" "${0##*/}: Either \`curl\` or \`wget\` must be installed"
    cd "$reset_dir"
    exit 1
fi

# Detect pager utility. Use `less` if possible, but `more` is POSIX.
pager=
if type less > /dev/null ; then
    pager=less
else
    pager=more
fi

match_version='[[:digit:]]+.[[:digit:]]+.[[:digit:]]+'

usage() {
    printf "sbup version %s\n" $sbup_version
    printf "\n"
    printf "%s\n" "Usage:"
    printf "%s\n" "------"
    printf "%s\n" "sbup [command] {Sbup options} [-- {SBCL options}]"
    printf "%s\n" ""
    printf "%s\n" "Commands:"
    printf "%s\n" "---------"
    printf "%s\n" "check   ... Check for new release of SBCL"
    printf "%s\n" ""
    printf "%s\n" "list    ... Show available SBCL versions"
    printf "%s\n" "            \`list\`, \`list recent\`"
    printf "%s\n" "                lists the most recent versions"
    printf "%s\n" "            \`list all\`"
    printf "%s\n" "                lists all available versions"
    printf "%s\n" "            \`list <N>\`"
    printf "%s\n" "                lists the most recent <N> versions"
    printf "%s\n" "            \`list downloads\`, \`list downloaded\`, \`list dl\`"
    printf "%s\n" "                lists all downloaded SBCL tarballs"
    printf "%s\n" "            \`list built\`, \`list b\`"
    printf "%s\n" "                lists all available SBCL builds"
    printf "%s\n" ""
    printf "%s\n" "get     ... Download SBCL tarball to current directory"
    printf "%s\n" "            \`get\`, \`get latest\`"
    printf "%s\n" "                downloads the most recent release"
    printf "%s\n" "            \`get <VERSION>\`"
    printf "%s\n" "                downloads the specified version"
    printf "%s\n" ""
    printf "%s\n" "build   ... Download SBCL tarball and build in current directory"
    printf "%s\n" "            Builds documentation unless \`--nodocs\` is specified"
    printf "%s\n" "            \`build\`, \`build latest\`"
    printf "%s\n" "                download latest release if necessary, then build"
    printf "%s\n" "            \`build <VERSION>\`"
    printf "%s\n" "                download specified version if necessary, then build"
    printf "%s\n" ""
    printf "%s\n" "test    ... Run SBCL test suite"
    printf "%s\n" "            \`test\`, \`test latest\`"
    printf "%s\n" "                run tests for the most recent release"
    printf "%s\n" "            \`test <VERSION>\`"
    printf "%s\n" "                run tests for the specified version"
    printf "%s\n" ""
    printf "%s\n" "update  ... Download, build, test and install SBCL"
    printf "%s\n" "            Download and build as necessary"
    printf "%s\n" "            Builds documentation unless \`--nodocs\` is specified"
    printf "%s\n" "            Runs tests unless \`--notest\` is specified"
    printf "%s\n" "            Installs SBCL unless \`--noinstall\` is specified"
    printf "%s\n" "            \`update\`, \`update latest\`"
    printf "%s\n" "                update to most recent release"
    printf "%s\n" "            \`update <VERSION>\`"
    printf "%s\n" "                update to specified version"
    printf "%s\n" ""
    printf "%s\n" "install ... Alias for \`update\`"
    printf "%s\n" ""
    printf "%s\n" "help    ... Show this help screen"
    printf "%s\n" ""
    printf "%s\n" "Options:"
    printf "%s\n" "--------"
    printf "%s\n" "-i | --install_root ... Configure SBCL \`INSTALL_ROOT\`"
    printf "%s\n" ""
    printf "%s\n" "--nodocs            ... Disable building of documentation"
    printf "%s\n" "                        Used with \`build\` and \`update\`"
    printf "%s\n" ""
    printf "%s\n" "--noinstall         ... Disable final installation"
    printf "%s\n" "                        Used with \`update\`"
    printf "%s\n" ""
    printf "%s\n" "--notest            ... Disable running of tests"
    printf "%s\n" "                        Used with \`update\`"
    printf "%s\n" ""
    printf "%s\n" "-u | --user         ... Enable user installation (without \`sudo\`)"
}

script_fail() {
    printf "*** %s : %s ***\n" "$1" "$2" >&2
    #usage
    cd "$reset_dir"
    exit 2
}

# Check for installed SBCL
if ! type sbcl ; then
    printf "%s\n" "SBCL is not currently installed: no update possible"
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

# Get available versions.
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

check_sbcl() {
    if [ "$cur_ver" = "$sbcl_latest_available" ]
    then
        printf "%s\n" "Already using most recent SBCL: $cur_ver"
    elif [ "$sbcl_latest_built" = "$sbcl_latest_available" ]
    then
        printf "%s\n" "Most recent SBCL already built: $sbcl_latest_built"
    elif [ "$sbcl_latest_downloaded" = "$sbcl_latest_available" ]
    then
        printf "%s\n" "Most recent SBCL already downloaded: $sbcl_latest_downloaded"
    else
        printf "%s\n" "New version of SBCL available: $sbcl_latest_available"
    fi
}

display_version() {
    if [ "$1" = "$cur_ver" ]
    then printf "> %s <\n" "$1"
    else printf "  %s\n" "$1"
    fi
}

list_available() {
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
            display_version "$sbcl_version" ; continue
        elif [ $sbcl_show_count -eq 0 ] ;
        then
            break
        else
            display_version "$sbcl_version" ; sbcl_show_count=$((sbcl_show_count-1))
        fi
    done
}

# Download SBCL to current directory.
download_sbcl() {
    downloading_url="$sbcl_files_dl/$building_version/sbcl-$building_version-source.tar.bz2"
    printf "%s\n" "Downloading SBCL $building_version..."
    case "$downloader" in
        curl )
            curl -L "$downloading_url" --remote-name ;;
        wget )
            wget -q --show-progress "$downloading_url" ;;
        *)
            script_fail "Unrecognized downloader" "$downloader" ;;  # should never happen
    esac
}

# Extract SBCL build directory into current directory.
unpack_sbcl() {
    if [ -f $building_file ]
    then
        printf "%s\n" "Unpacking SBCL $building_version..."
        tar -xvf $building_file
    else
        script_fail "SBCL tarball not found" "$building_version"
    fi
}

build_sbcl() {
    if [ -d $building_dir ]
    then
        printf "%s\n" "Building SBCL $building_version..."
        cd $building_dir
        sh make.sh $@
    else
        script_fail "SBCL version not extracted" "$building_version"
    fi
}

test_sbcl() {
    if [ -d $building_dir ] && [ -d $building_dir/obj ]
    then
        printf "%s\n" "Running SBCL $building_version tests..."
        cd $building_dir/tests
        sh run-tests.sh
    else
        script_fail "SBCL version not built" "$building_version"
    fi
}

build_sbcl_docs() {
    if [ -d $building_dir ] && [ -d $building_dir/doc ]
    then
        printf "%s\n" "Building SBCL $building_version documentation..."
        cd $building_dir/doc/manual
        make
    else
        script_fail "No documentation directory found" "$building_dir/doc"
    fi
}

install_sbcl() {
    if [ -d $building_dir ] && [ -d $building_dir/obj ]
    then
        printf "%s\n" "Installing SBCL $building_version..."
        cd $building_dir
        export INSTALL_ROOT="$1"
        $2 sh install.sh
        unset INSTALL_ROOT
    else
        script_fail "SBCL version not built" "$building version"
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
        OPT=${OPTARG%%=*}      # get long option
        OPTARG=${OPTARG#$OPT}  # get long option argument
        OPTARG=${OPTARG#=}
    fi
    case "$OPT" in
        i | install_root )
            require_arg
            no_tilde=${OPTARG#"~/"}
            if [ "$no_tilde" = "$OPTARG" ] ; then
                install_root="$no_tilde"
            else
                install_root="$HOME/$no_tilde"
            fi
            ;;
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
                    display_version "$dl"
                done
                ;;
            b | built)
                printf "available SBCL builds:\n"
                for build in $sbcl_built ; do
                    display_version "$build"
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
                # download_sbcl "$sbcl_latest_available"
                building_version="$sbcl_latest_available"
                ;;
            * )
                if ! $(echo "$modifier" | grep -E ^$match_version > /dev/null) ; then
                    script_fail "Not a version number" "$command $modifer"
                elif ! $(echo "$sbcl_available" | grep "$modifier" > /dev/null) ; then
                    script_fail "Version not available" "$command $modifier"
                fi
                building_version="$modifier"
                ;;
        esac
        download_sbcl
        ;;
    build )
        case "$modifier" in
            "" | latest )
                building_version="$sbcl_latest_available"
                ;;
            * )
                if ! $(echo "$modifier" | grep -E ^$match_version > /dev/null) ; then
                    script_fail "Not a version number" "$command $modifer"
                fi
                building_version="$modifier"
                ;;
        esac
        building_file="$sbup_dir/sbcl-$building_version-source.tar.bz2"
        building_dir="$sbup_dir/sbcl-$building_version"
        if ! [ -f "$building_file" ] ; then
            printf "%s\n" "$building_file"
            download_sbcl
        fi
        if ! [ -d "$building_dir" ] ; then
            unpack_sbcl
        fi
        if ! [ -d $building_dir/obj ]
        then
            build_sbcl $make_suffix
        fi
        if [ -z "$nodocs" ] ; then
            build_sbcl_docs
        fi
        ;;
    test )
        case "$modifier" in
            "" | latest )
                building_version="$sbcl_latest_available"
                ;;
            * )
                if ! $(echo "$modifier" | grep -E ^$match_version > /dev/null) ; then
                    script_fail "Not a version number" "$command $modifer"
                fi
                building_version="$modifier"
                ;;
        esac
        building_dir="$sbup_dir/sbcl-$building_version"
        test_sbcl
        ;;
    update | install )
        case "$modifier" in
            "" | latest )
                building_version="$sbcl_latest_available"
                ;;
            * )
                if ! $(echo "$modifier" | grep -E ^$match_version > /dev/null) ; then
                    script_fail "Not a version number" "$command $modifer"
                fi
                building_version="$modifier"
                ;;
        esac
        building_file="$sbup_dir/sbcl-$building_version-source.tar.bz2"
        building_dir="$sbup_dir/sbcl-$building_version"
        if ! [ -f "$building_file" ] ; then
            download_sbcl
        fi
        if ! [ -d "$building_dir" ] ; then
            unpack_sbcl
        fi
        if ! [ -d $building_dir/obj ]
        then
            build_sbcl $make_suffix
        fi
        if [ -z "$notest" ] ; then
            test_sbcl
        fi
        if [ -z "$nodocs" ] ; then
            build_sbcl_docs
        fi
        if [ -z "$noinstall" ] ; then
            install_sbcl "$install_root" "$install_mode"
        fi
        ;;
    help | "" )
        usage | $pager
        ;;
    * )
        script_fail "Unrecognized command" "$command"
        ;;
esac

cd "$reset_dir"
