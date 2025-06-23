FUZZ="--fuzz"
directory="$(pwd)"
mkdir -p logs
CONFIG="all"
pkill ns-slapd
LOG_OUPTUT=1
PACKET_CAPTURE=0

mkdir logs/old
cp logrotate.conf run/logrotate.conf
sed -i s!tacos!$directory!g run/logrotate.conf

_term() {
    for fuzzerpid in $puzzerpids; do
        kill -TERM "$fuzzerpid" 2>/dev/null
    done
    exit
}

trap _term SIGTERM

pids=()

config_build() {
    case "${BUILD_CONFIG}" in

    1)
        config_flags="-d errors"
        ;;
    2)
        config_flags="-d ALL"
        ;;
    3)
        config_flags="-d parsing+errors"
        ;;
    4)
        config_flags="-d trace"
        ;;
    5)
        config_flags="-d 4"
        ;;
    6)
        config_flags="-d parsing+errors"
        ;;
    7)
        config_flags="-d ALL"
        ;;
    8)
        config_flags="-d 8"
        ;;
    9)
        config_flags=""
        ;;
    10)
        config_flags=""
        ;;
    11)
        config_flags="-d 16"
        ;;
    12)
        config_flags="-d 256"
        ;;
    13)
        config_flags="-d 32"
        ;;
    14)
        config_flags="-d 64"
        ;;
    15)
        config_flags="-d 128"
        ;;
    16)
        config_flags="-d 16"
        ;;
    17)
        config_flags="-d 16"
        ;;
    18)
        config_flags="-d 16"
        ;;
    19)
        config_flags="-d 16"
        ;;
    20)
        config_flags="-d 16"
        ;;

    \
        *)
        echo "Bad case. Try again."
        echo "Argument should be number 1-10"
        exit 1
        ;;
    esac
}

run_fuzzer() {
    config_build
    rm -rf /tmp/slapd_${BUILD_CONFIG}

    if [ $LOG_OUPTUT = 1 ]; then
        echo "ASAN_OPTIONS=strict_string_checks=1:detect_stack_use_after_return=1:check_initialization_order=1:strict_init_order=1:log_path=$directory/logs/asan$BUILD_CONFIG.log:halt_on_error=0 UBSAN_OPTIONS=halt_on_error=0 LSAN_OPTIONS=detect_leaks=0 $directory/run/run_$BUILD_CONFIG/sbin/ns-slapd -D $directory/run/run_$BUILD_CONFIG/etc/dirsrv/slapd-test-instance -i $directory/run/run_$BUILD_CONFIG/run/dirsrv/slapd-test-instance.pid $config_flags $FUZZ  >> $directory/logs/error$BUILD_CONFIG 2>>$directory/logs/error$BUILD_CONFIG &"
        FUZZER_DEBUG=1 ASAN_OPTIONS=strict_string_checks=1:detect_stack_use_after_return=1:check_initialization_order=1:strict_init_order=1:log_path=$directory/logs/asan$BUILD_CONFIG.log:halt_on_error=0 LSAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=0 $directory/run/run_$BUILD_CONFIG/sbin/ns-slapd -D $directory/run/run_$BUILD_CONFIG/etc/dirsrv/slapd-test-instance -i $directory/run/run_$BUILD_CONFIG/run/dirsrv/slapd-test-instance.pid $config_flags $FUZZ >>$directory/logs/error$BUILD_CONFIG 2>>$directory/logs/error2$BUILD_CONFIG &

    else

        echo "ASAN_OPTIONS=strict_string_checks=1:detect_stack_use_after_return=1:check_initialization_order=1:strict_init_order=1:log_path=$directory/logs/asan$BUILD_CONFIG.log:halt_on_error=0 UBSAN_OPTIONS=halt_on_error=0 LSAN_OPTIONS=detect_leaks=0 $directory/run/run_$BUILD_CONFIG/sbin/ns-slapd -D $directory/run/run_$BUILD_CONFIG/etc/dirsrv/slapd-test-instance -i $directory/run/run_$BUILD_CONFIG/run/dirsrv/slapd-test-instance.pid $config_flags $FUZZ &"
        FUZZER_DEBUG=1 ASAN_OPTIONS=strict_string_checks=1:detect_stack_use_after_return=1:check_initialization_order=1:strict_init_order=1:log_path=$directory/logs/asan$BUILD_CONFIG.log:halt_on_error=0 UBSAN_OPTIONS=halt_on_error=0 LSAN_OPTIONS=detect_leaks=0 $directory/run/run_$BUILD_CONFIG/sbin/ns-slapd -D $directory/run/run_$BUILD_CONFIG/etc/dirsrv/slapd-test-instance -i $directory/run/run_$BUILD_CONFIG/run/dirsrv/slapd-test-instance.pid $config_flags $FUZZ &
    fi

    fuzzerpids+=($!)
}

for arg in "$@"; do
    case "$arg" in
    --fuzz | -f)
        FUZZ=" "
        ;;

    --packet | -p)
        PACKET_CAPTURE=1
        ;;

    --config=* | -c=*) CONFIG="${arg#*=}" ;;

    --LOG_OUPTUT | -s)
        LOG_OUPTUT=0
        ;;

    esac
done

logrotate --force run/logrotate.conf -s logs/old/logrotate.status

if [ ${PACKET_CAPTURE} = 1 ]; then
    # if [ "$EUID" -ne 0 ]
    #   then echo "Please run with sudo"
    #   exit
    # fi
    tcpdump -G 43200 -i lo ip6 -w logs/dump$$.pcap -z gzip &
    fuzzerpids+=($!)
    sleep 5
fi

if [ "$CONFIG" = "a" ] || [ "$CONFIG" = "all" ]; then
    for BUILD_CONFIG in {1..20}; do
        sleep 0.1
        run_fuzzer
    done
else
    BUILD_CONFIG=$CONFIG
    run_fuzzer
fi

while :; do
    sleep 30
    logrotate run/logrotate.conf -s logs/old/logrotate.status
done

# {LDAP_DEBUG_TRACE, "trace", 0},
# {LDAP_DEBUG_PACKETS, "packets", 0},
# {LDAP_DEBUG_ARGS, "arguments", 0},
# {LDAP_DEBUG_ARGS, "args", 1},
# {LDAP_DEBUG_CONNS, "connections", 0},
# {LDAP_DEBUG_CONNS, "conn", 1},
# {LDAP_DEBUG_CONNS, "conns", 1},
# {LDAP_DEBUG_BER, "ber", 0},
# {LDAP_DEBUG_FILTER, "filters", 0},
# {LDAP_DEBUG_CONFIG, "config", 0},
# {LDAP_DEBUG_ACL, "accesscontrol", 0},
# {LDAP_DEBUG_ACL, "acl", 1},
# {LDAP_DEBUG_ACL, "acls", 1},
# {LDAP_DEBUG_STATS, "stats", 0},
# {LDAP_DEBUG_STATS2, "stats2", 0},
# {LDAP_DEBUG_SHELL, "shell", 1},
# {LDAP_DEBUG_PARSE, "parsing", 0},
# {LDAP_DEBUG_HOUSE, "housekeeping", 0},
# {LDAP_DEBUG_REPL, "replication", 0},
# {LDAP_DEBUG_REPL, "repl", 1},
# {LDAP_DEBUG_ANY, "errors", 0},
# {LDAP_DEBUG_ANY, "ANY", 1},
# {LDAP_DEBUG_ANY, "error", 1},
# {LDAP_DEBUG_CACHE, "caches", 0},
# {LDAP_DEBUG_CACHE, "cache", 1},
# {LDAP_DEBUG_PLUGIN, "plugins", 0},
# {LDAP_DEBUG_PLUGIN, "plugin", 1},
# {LDAP_DEBUG_TIMING, "timing", 0},
# {LDAP_DEBUG_ACLSUMMARY, "accesscontrolsummary", 0},
# {LDAP_DEBUG_BACKLDBM, "backend", 0},
# {LDAP_DEBUG_ALL_LEVELS, "ALL", 0},
