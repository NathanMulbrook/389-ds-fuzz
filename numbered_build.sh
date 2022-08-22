#!/usr/bin/env bash

pkill ns-slapd

export CC=clang
export CXX=clang++
export LSAN_OPTIONS=detect_leaks=0

PATCH=1
CONFIG="a"
BUILD_INIT=0
BUILD_DIRECTORY=0
REBUILD_DIRECTORY=0

#--enable-debug  --with-openldap --enable-mmap --with-asan --enable-dnstap --with-libevent

export CFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4  -m64 -mtune=generic  -fsanitize-recover=all'
export CXXFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 --param=ssp-buffer-size=4 -m64 -mtune=generic  -fsanitize-recover=all'
export config_flags_default="--enable-asan --enable-ubsan --enable-rust --enable-clang"


cleanup()
{
  cd 389-ds-base || exit
  git apply -R ../patches/*.patch
  cd ..
}


patch_build()
{
  cd 389-ds-base || exit
  git reset --hard
  git apply --reject --ignore-space-change --ignore-whitespace  ../patches/*.patch
  cd ..
}


help()
{
  echo "Is a useful program"
  echo "Read the source. kthxbai"
}


config_build()
{
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


      *) echo "Bad case. Try again.";
        echo "Argument should be number 1-10"
        exit 1;;
    esac
}


build_software()
{
  run_dir="run_${BUILD_CONFIG}"
  directory="$(pwd)"
  build_dir="build"
  port=$(($BUILD_CONFIG+5555))
  portsec=$(($BUILD_CONFIG+5700))
  rm $directory/run_$BUILD_CONFIG/sbin/ns-slapd

  if [ ${BUILD_DIRECTORY} = 1 ]; then
    rm -rf "$run_dir"
  fi

  if [ ${REBUILD_DIRECTORY} = 0 ]; then
    rm -rf "$build_dir"
  fi

  mkdir -p "$build_dir"
  mkdir -p "$run_dir/sbin"
  mkdir -p "$run_dir/sbin/corpus"
  mkdir -p corpus

  if [ ${REBUILD_DIRECTORY} = 0 ]; then
    sleep 2

    cp fuzzer.c 389-ds-base/ldap/servers/slapd/fuzzer.c
    cp fuzzer.h 389-ds-base/ldap/servers/slapd/fuzzer.h

    sed -i s/5555/$port/g 389-ds-base/ldap/servers/slapd/fuzzer.c
    sed -i s#/home/admin/software/fuzzing/389ds-test/389ds-fuzz#$directory#g 389-ds-base/ldap/servers/slapd/fuzzer.c
    sed -i "s#char\spathToTestCaseLog.*#char pathToTestCaseLog[] = \"${directory}/logs/testCases${BUILD_CONFIG}\";#g" \
     389-ds-base/ldap/servers/slapd/filter.c 389-ds-base/ldap/servers/slapd/attrsyntax.c 389-ds-base/ldap/servers/slapd/libglobs.c \
     389-ds-base/ldap/servers/slapd/back-ldbm/cache.c 389-ds-base/ldap/servers/slapd/util.c 389-ds-base/ldap/servers/slapd/fuzzer.c \
     389-ds-base/ldap/servers/slapd/valueset.c

    cd "$build_dir" || cleanup

    ../389-ds-base/configure $config_flags  --with-localrundir="$directory/$run_dir/run" --exec-prefix="$directory/$run_dir/" --prefix="$directory/$run_dir/" || exit 5
      sleep 2

    make clean
    cd ..
  fi 

  cd "$build_dir" || exit
  make install -j$(($(nproc)-1))
  # || exit 6
  make lib389 -j$(($(nproc)-1))
  # || exit 7
    sleep 2

  cd "../$run_dir" || cleanup
  cp ../$build_dir/.libs/*.so lib/dirsrv/plugins/




  if [ ${BUILD_DIRECTORY} = 1 ]; then
    cp ../dssetup.inf dssetup.inf
    echo "prefix = $directory/$run_dir/" >> dssetup.inf
    echo "lock_dir =  $directory/$run_dir/run/lock/dirsrv/slapd-{instance_name}" >> dssetup.inf
    echo "run_dir = $directory/$run_dir/run/dirsrv" >> dssetup.inf
    echo "ldapi = $directory/$run_dir/run/slapd-{instance_name}.socket" >> dssetup.inf
    echo "pid_file = $directory/$run_dir/run/dirsrv/slapd-{instance_name}.pid" >> dssetup.inf
    sed -i s/admin/$(whoami)/g dssetup.inf

    sed -i s/5555/$port/g dssetup.inf
    sed -i s/6667/$portsec/g dssetup.inf

    echo  "$directory/389-ds-base/src/lib389"
    sleep 2

    PYTHONPATH="$PYTHONPATH:$directory/389-ds-base/src/lib389" PREFIX="$directory/$run_dir/" ../389-ds-base/src/lib389/cli/dscreate from-file ./dssetup.inf
    if [ $? -ne 0 ]; then
      cd ..
      ./numbered_build.sh -c=$BUILD_CONFIG -r
      cd "$run_dir" || cleanup
      echo $?
    fi
  fi
  cd ..
  # if [ ${REBUILD_DIRECTORY} = 0 ]; then
  #   ./numbered_build.sh -c=${BUILD_CONFIG} -r
  # fi

}




for arg in "$@"
do
  case "$arg" in
    --help|-h)
      help
      exit
      ;;

    --directory|-d)
      BUILD_DIRECTORY=1
      ;;

    --rebuild-directory|-r)
      REBUILD_DIRECTORY=1
      BUILD_DIRECTORY=1
      ;;

    --init|-i)
      BUILD_INIT=1
      ;;

    --no_patch|-p) export PATCH=0 ;;

    --config=*|-c=*) CONFIG="${arg#*=}" ;;

  esac
done

if [ ${REBUILD_DIRECTORY} = 1 ] && [ "$CONFIG" = "a" ]; then
  echo "Incompatible Aarguents"
  exit
fi

if [ ${BUILD_INIT} = 1 ]; then
  git clone git@github.com:NathanMulbrook/389-ds-base.git
  cd 389-ds-base || cleanup
  git checkout fuzz
  ./autogen.sh
  cd ..
fi


if [ $PATCH = 1 ] ; then
  patch_build
fi

if [ "$CONFIG" = "a" ] || [ "$CONFIG" = "all" ]; then
  for BUILD_CONFIG in {1..20}
  do
    config_build
    build_software
done

else
  BUILD_CONFIG="$CONFIG"
  config_build
  build_software
fi
sleep 2


pkill ns-slapd
cleanup

