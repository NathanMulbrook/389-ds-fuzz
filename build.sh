#!/usr/bin/env bash
export CC='clang'
export CXX='clang++'
export LSAN_OPTIONS=detect_leaks=0
if [ -f "/home/$(whoami)/.cargo/bin" ]; then
    export PATH=$PATH:/home/$(whoami)/.cargo/bin
    export RUSTC_WRAPPER=sccache
    echo "Using sccache!!"
# else
#     echo "Not using sccache!!"
#     exit
fi

PATCH=1
CONFIG="a"
BUILD_INIT=0
BUILD_DIRECTORY=0
REBUILD_DIRECTORY=0
JOBS=1 #setting 1 often causes build fails
PATCHBRANCH="master"
PRIVATEBRANCH="master"
#A389BRANCH="3db81913e27002ced7df00e5625b804457593efb"
#A389BRANCH="41add0d6576232a0e1d4096670f0fd9e2f60baa9" #2.3.6
#A389BRANCH="a8f062ef90a6e5d5d4095fbe1838dcde82e835d9" #2.3.5
A389BRANCH="41add0d6576232a0e1d4096670f0fd9e2f60baa9" #2.3.8

PATCHDIRS=(
    "389-ds-patches/patches"
    "389-ds-private/patches"
)

directory="$(pwd)"
source_dir="$directory/389-ds-base"

export CFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector -Wno-implicit-function-declaration  -Wno-everything -ferror-limit=0  -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4  -m64 -mtune=generic  -fsanitize-recover=all -fsanitize=fuzzer-no-link,address,undefined  -fprofile-instr-generate  -fcoverage-mapping'
export CXXFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector -Wno-implicit-function-declaration -Wno-everything -ferror-limit=0  -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4 -m64 -mtune=generic  -fsanitize-recover=all -fsanitize=fuzzer-no-link,address,undefined  -fprofile-instr-generate  -fcoverage-mapping'
export config_flags_default="--enable-asan --enable-ubsan --enable-rust --enable-clang --disable-dependency-tracking"

#Configs for the differnt builds
config_build() {
    echo "############# Buiding Config: $BUILD_CONFIG ##################"
    case "${BUILD_CONFIG}" in
    1)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    2)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    3)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    4)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    5)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    6)
        config_flags="${config_flags_default} --enable-debug "
        ;;
    7)
        config_flags="${config_flags_default} --enable-debug "
        ;;
    8)
        config_flags="${config_flags_default} --enable-debug "
        ;;
    9)
        config_flags="${config_flags_default} "
        ;;
    10)
        config_flags="${config_flags_default} "
        ;;
    11)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    12)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    13)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    14)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    15)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    16)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    17)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    18)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    19)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;
    20)
        config_flags="${config_flags_default} --enable-debug --with-openldap"
        ;;

    *)
        echo "Bad case. Try again."
        echo "Argument should be number 1-10"
        exit 1
        ;;
    esac
}

list_descendants() {
    local children=$(ps -o pid= --ppid "$1")
    for pid in $children; do
        list_descendants "$pid"
    done
    echo "$children"
}

_term() {
    echo "Killing Children"
    kill $(list_descendants $$)
    kill -9 $(list_descendants $$)
    exit
}

trap _term SIGINT
trap _term INT

build_failed() {
    echo "BUILD FAILED!!"
    exit
}

help() {
    echo "Is a useful program"
    echo "Read the source. kthxbai"
    exit
}

build_software() {
    echo "############# Buiding Config: $BUILD_CONFIG Args Used: $@ ##################"
    run_dir="$directory/run/run_${BUILD_CONFIG}"
    build_dir="$directory/build/build_${BUILD_CONFIG}"
    temp_source_dir="$directory/build/src_${BUILD_CONFIG}"
    port=$(($BUILD_CONFIG + 5600))
    portsec=$(($BUILD_CONFIG + 5700))

    rm "$run_dir/sbin/ns-slapd" || (build_failed)
    pkill -9 -f "run_$BUILD_CONFIG/sbin/ns-slapd"
    if [ ${BUILD_DIRECTORY} = 1 ]; then
        rm -rf "$run_dir" || (build_failed)
    fi
    if [ ${REBUILD_DIRECTORY} = 0 ]; then
        rm -rf "$build_dir" || (build_failed)
        rm -rf "$temp_source_dir" || (build_failed)
    fi

    mkdir -p "$temp_source_dir"
    mkdir -p "$build_dir"
    mkdir -p "$directory/run"
    mkdir -p "$run_dir"
    mkdir -p "$run_dir/sbin"
    mkdir -p "$directory/corpus"

    if [ ${REBUILD_DIRECTORY} = 0 ]; then
        cp -r "$source_dir"/. "$temp_source_dir"
        cd "$temp_source_dir" || (build_failed)
        if [ $PATCH = 1 ]; then
            for PATCHDIR in $PATCHDIRS; do
                git apply -v --reject --ignore-space-change --ignore-whitespace "$directory"/"$PATCHDIR"/*.patch || build_failed
                printf "Applied patches from %s\n" "$PATCHDIR"
            done
        fi
        ./autogen.sh
        echo "======Autogen done======"
        cd "$build_dir" || build_failed
        cp "$directory"/fuzzer.c "$temp_source_dir"/ldap/servers/slapd/fuzzer.c || build_failed
        cp "$directory"/fuzzer.h "$temp_source_dir"/ldap/servers/slapd/fuzzer.h || build_failed

        sed -i s/5555/$port/g "$temp_source_dir"/ldap/servers/slapd/fuzzer.c
        sed -i s!/home/admin/software/fuzzing/389ds-test/389ds-fuzz!$directory!g "$temp_source_dir"/ldap/servers/slapd/fuzzer.c
        sed -i "s#char\spathToTestCaseLog.*#char pathToTestCaseLog[] = \"${directory}/logs/testCases${BUILD_CONFIG}\";#g" \
            "$temp_source_dir"/ldap/servers/slapd/filter.c "$temp_source_dir"/ldap/servers/slapd/attrsyntax.c "$temp_source_dir"/ldap/servers/slapd/libglobs.c \
            "$temp_source_dir"/ldap/servers/slapd/back-ldbm/cache.c "$temp_source_dir"/ldap/servers/slapd/util.c "$temp_source_dir"/ldap/servers/slapd/fuzzer.c \
            "$temp_source_dir"/ldap/servers/slapd/valueset.c

        config_build
        "$temp_source_dir"/configure $config_flags --with-localrundir="$run_dir/run" --exec-prefix="$run_dir/" --prefix="$run_dir/" || build_failed 5
        echo "======Configure done======"
        make clean
    fi
    cd "$build_dir" || build_failed

    make install -j $JOBS
    if [ $? -ne 0 ] && [ $JOBS = 1 ]; then
        echo "########### make failed, retrying ###########"
        cd "$directory" || build_failed
        #./build.sh $@
        exit
    fi
    if [ $JOBS -ne 1 ]; then
        make lib389 -j $JOBS
        cp "$build_dir"/.libs/*.so "$run_dir"/lib/dirsrv/plugins/ || build_failed
    fi
    cd "$run_dir" || build_failed

    if [ ${BUILD_DIRECTORY} = 1 ]; then
        cp "$directory/dssetup.inf" "$run_dir/dssetup.inf"
        echo "prefix = $run_dir/" >>"$run_dir/dssetup.inf"
        echo "lock_dir =  $run_dir/run/lock/dirsrv/slapd-{instance_name}" >>"$run_dir"/dssetup.inf
        echo "run_dir = $run_dir/run/dirsrv" >>"$run_dir"/dssetup.inf
        echo "ldapi = $run_dir/run/slapd-{instance_name}.socket" >>"$run_dir"/dssetup.inf
        echo "pid_file = $run_dir/run/dirsrv/slapd-{instance_name}.pid" >>"$run_dir"/dssetup.inf
        echo "tmp_dir =  /tmp/slapd_${BUILD_CONFIG}" >>"$run_dir"/dssetup.inf
        echo "db_home_dir = /dev/shm/slapd-${BUILD_CONFIG}" >>"$run_dir"/dssetup.inf

        sed -i s/admin/$(whoami)/g "$run_dir"/dssetup.inf
        sed -i s/5555/$port/g "$run_dir"/dssetup.inf
        sed -i s/6667/$portsec/g "$run_dir"/dssetup.inf

        PYTHONPATH="$PYTHONPATH:$temp_source_dir/src/lib389" PREFIX="$run_dir/" ASAN_OPTIONS="log_path=/home/admin/software/fuzzing/389ds-test/389-ds-fuzz/logs/asan$BUILD_CONFIG.log:halt_on_error=0" UBSAN_OPTIONS="halt_on_error=0" LSAN_OPTIONS="detect_leaks=0" "$temp_source_dir"/src/lib389/cli/dscreate -v from-file "$run_dir"/dssetup.inf
        if [ $? -ne 0 ]; then
            cd "$directory" || build_failed
            echo "########### dscreate failed, retrying ###########"
            ./build.sh -c=$BUILD_CONFIG -r
            exit
        fi
    fi
    cd "$directory" || build_failed
    pkill -9 -f "run_$BUILD_CONFIG/sbin/ns-slapd"
}

for arg in "$@"; do
    case "$arg" in
    --help | -h)
        help
        exit
        ;;

    #builds the directory, this usually only needs ran once durring the first build.
    --directory | -d)
        BUILD_DIRECTORY=1
        ;;

    #used for recursive builds that fail.
    --rebuild-directory | -r)
        REBUILD_DIRECTORY=1
        BUILD_DIRECTORY=1
        export PATCH=0
        ;;

    #clone source code
    --init | -i)
        BUILD_INIT=1
        ;;
    --jobs | -j)
        JOBS=$(($(nproc) - 1))
        ;;

    --no_patch | -p) export PATCH=0 ;;

    --config=* | -c=*) CONFIG="${arg#*=}" ;;

    esac
done

if [ ${REBUILD_DIRECTORY} = 1 ] && [ "$CONFIG" = "a" ]; then
    echo "Incompatible Arguents"
    exit
fi

if [ ${BUILD_INIT} = 1 ]; then
    cd "$directory" || build_failed
    git clone git@github.com:NathanMulbrook/389-ds-base.git
    cd "$temp_source_dir" || build_failed
    git checkout $A389BRANCH
    cd "$directory" || build_failed
    git clone git@github.com:NathanMulbrook/389-ds-patches.git
    cd 389-ds-patches || build_failed
    git checkout $PATCHBRANCH
    cd "$directory" || build_failed
    git clone git@github.com:NathanMulbrook/389-ds-private.git
    cd 389-ds-private || build_failed
    git checkout $PRIVATEBRANCH
    cd "$directory" || build_failed
fi

cd 389-ds-base || build_failed
git checkout $A389BRANCH || build_failed
cd "$directory" || build_failed

cd 389-ds-patches || build_failed
git checkout $PATCHBRANCH || build_failed
cd "$directory" || build_failed

cd 389-ds-private || build_failed
git checkout $PRIVATEBRANCH || build_failed
cd "$directory" || build_failed

if [ "$CONFIG" = "a" ] || [ "$CONFIG" = "all" ]; then
    logrotate --force run/logrotate.conf -s logs/old/logrotate.status
    for BUILD_CONFIG in {1..20}; do
        ./build.sh -c=$BUILD_CONFIG $@ make 2>&1 | tee $directory/logs/build$BUILD_CONFIG.log &
        fuzzerpids+=($!)
        sleep 0.1
    done
    # while :; do
    #     sleep 5
    # done
    wait
else
    BUILD_CONFIG="$CONFIG"
    build_software $@
fi

#   --disable-option-checking  ignore unrecognized --enable/--with options
#   --disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
#   --enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
#   --enable-silent-rules   less verbose build output (undo: "make V=1")
#   --disable-silent-rules  verbose build output (undo: "make V=0")
#   --enable-maintainer-mode
#                           enable make rules and dependencies not useful (and
#                           sometimes confusing) to the casual installer
#   --enable-dependency-tracking
#                           do not reject slow dependency extractors
#   --disable-dependency-tracking
#                           speeds up one-time build
#   --enable-static[=PKGS]  build static libraries [default=no]
#   --enable-shared[=PKGS]  build shared libraries [default=yes]
#   --enable-fast-install[=PKGS]
#                           optimize for fast installation [default=yes]
#   --disable-libtool-lock  avoid locking (might break parallel builds)
#   --enable-rust-offline   Enable rust building offline. you MUST have run
#                           vendor! (default: no)
#   --enable-rust           Enable rust language features (default: no)
#   --enable-cockpit        Enable cockpit plugin (default: yes)
#   --enable-debug          Enable debug features (default: no)
#   --enable-asan           Enable gcc/clang address sanitizer options (default:
#                           no)
#   --enable-msan           Enable gcc/clang memory sanitizer options (default:
#                           no)
#   --enable-tsan           Enable gcc/clang thread sanitizer options (default:
#                           no)
#   --enable-tsan           Enable gcc/clang undefined behaviour sanitizer
#                           options (default: no)
#   --enable-clang          Enable clang (default: no)
#   --enable-cfi            Enable control flow integrity - requires
#                           --enable-clang (default: no)
#   --enable-gcc-security   Enable gcc secure compilation options (default: no)
#   --enable-profiling      Enable gcov profiling features (default: no)
#   --enable-systemtap      Enable systemtap probe features (default: no)
#   --enable-pam-passthru   enable the PAM passthrough auth plugin (default:
#                           yes)
#   --enable-dna            enable the Distributed Numeric Assignment (DNA)
#                           plugin (default: yes)
#   --enable-ldapi          enable LDAP over unix domain socket (LDAPI) support
#                           (default: yes)
#   --enable-autobind       enable auto bind over unix domain socket (LDAPI)
#                           support (default: no)
#   --enable-auto-dn-suffix enable auto bind with auto dn suffix over unix
#                           domain socket (LDAPI) support (default: no)
#   --enable-bitwise        enable the bitwise matching rule plugin (default:
#                           yes)
#   --enable-acctpolicy     enable the account policy plugin (default: yes)
#   --enable-posix-winsync  enable support for POSIX user/group attributes in
#                           winsync (default: yes)
#   --enable-cmocka         Enable cmocka unit tests (default: no)

# Optional Packages:
#   --with-PACKAGE[=ARG]    use PACKAGE [ARG=yes]
#   --without-PACKAGE       do not use PACKAGE (same as --with-PACKAGE=no)
#   --with-pic[=PKGS]       try to use only PIC/non-PIC objects [default=use
#                           both]
#   --with-aix-soname=aix|svr4|both
#                           shared library versioning (aka "SONAME") variant to
#                           provide on AIX, [default=aix].
#   --with-gnu-ld           assume the C compiler uses GNU ld [default=no]
#   --with-sysroot[=DIR]    Search for dependent libraries within DIR (or the
#                           compiler's sysroot if not specified).
#   --with-fhs              Use FHS layout
#   --with-fhs-opt          Use FHS optional layout
#   --with-localrundir=DIR  Runtime data directory
#   --with-perldir=PATH     Directory for perl

#   --with-pythonexec=PATH  Path to executable for python

#   --with-instconfigdir=/path
#                           Base directory for instance specific writable
#                           configuration directories (default
#                           $sysconfdir/$PACKAGE_NAME)
#   --with-initddir=/path   Absolute path (not relative like some of the other
#                           options) that should contain the SysV init scripts
#                           (default '$(sysconfdir)/rc.d')
#   --with-openldap[=PATH]  Use OpenLDAP - optional PATH is path to OpenLDAP SDK
#   --with-openldap-inc=PATH
#                           OpenLDAP SDK include directory
#   --with-openldap-lib=PATH
#                           OpenLDAP SDK library directory
#   --with-openldap-bin=PATH
#                           OpenLDAP SDK binary directory
#   --with-db[=PATH]        Berkeley DB directory
#   --with-db-inc=PATH      Berkeley DB include file directory
#   --with-db-lib=PATH      Berkeley DB library directory
#   --with-netsnmp[=PATH]   Net-SNMP directory
#   --with-netsnmp-inc=PATH Net-SNMP include directory
#   --with-netsnmp-lib=PATH Net-SNMP library directory
#   --with-selinux          Support SELinux features
#   --with-systemd          Enable Systemd native integration.
#   --with-journald         Enable Journald native integration. WARNING, this
#                           may cause system instability
#   --with-systemdsystemunitdir=PATH
#                           Directory for systemd service files (default:
#                           $with_systemdsystemunitdir)

#   --with-systemdsystemconfdir=PATH
#                           Directory for systemd service files (default:
#                           $with_systemdsystemconfdir)

#   --with-systemdgroupname=NAME
#                           Name of group target for all instances (default:
#                           $with_systemdgroupname)

#   --with-tmpfiles-d=PATH  system uses tmpfiles.d to handle temp files/dirs
#                           (default: $tmpfiles_d)

#   --with-libldap-r        Use lldap_r shared library (default: if OpenLDAP
#                           version is less than 2.5, then lldap_r will be used,
#                           else - lldap)
#
