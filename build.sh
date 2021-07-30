#!/usr/bin/env bash

set -e

# needed for freebsd
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

SRC=$(pwd);

# Get platform-specific values.
case $(uname -s) in
    'Linux')
        nproc=$(getconf _NPROCESSORS_ONLN)
        bd="yes"
        werror="-Werror"
        ;;
    'NetBSD'|'FreeBSD')
        nproc=$(getconf NPROCESSORS_ONLN)
        bd="no"
        werror=""
        ;;
    *)
        nproc=4
        bd="no"
        werror=""
esac

io_uring=""
brickmux=""
case $JOB_NAME in
    'gh_regression-test-with-multiplex'|'gh_regression-on-demand-multiplex')
        brickmux="--enable-brickmux"; io_uring="--disable-linux-io_uring"
        ;;
    'gh_smoke-centos7'|'gh_devrpm-el7'|'gh_centos7-regression'|'gh_regression-on-demand-full-run'|'gh_regression-test-burn-in')
        io_uring="--disable-linux-io_uring"
        ;;
esac

if type rpm >/dev/null 2>&1; then
    rpm -qa | grep glusterfs | xargs --no-run-if-empty rpm -e
fi
./autogen.sh;
P=/build;
rm -rf $P/scratch;
mkdir -p $P/scratch;
cd $P/scratch;
rm -rf $P/install;
$SRC/configure --prefix=$P/install --with-mountutildir=$P/install/sbin \
               --with-initdir=$P/install/etc --localstatedir=/var \
               --enable-debug --enable-gnfs --silent ${brickmux} ${io_uring}
make install CFLAGS="-Wall ${werror} -Wno-cpp" -j ${nproc}
cd $SRC;
