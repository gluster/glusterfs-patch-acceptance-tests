#!/usr/bin/env bash

set -e

# needed for freebsd
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

SRC=$(pwd);

# get nproc
case $(uname -s) in
    'Linux')
        local nproc=$(getconf _NPROCESSORS_ONLN)
        ;;
    'NetBSD')
        local nproc=$(getconf NPROCESSORS_ONLN)
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
$SRC/configure --prefix=$P/install --with-mountutildir=$P/install/sbin --with-initdir=$P/install/etc --localstatedir=/var --enable-bd-xlator=yes --enable-debug --silent
make install CFLAGS="-g -O0 -Wall -Werror" -j ${nproc} >/dev/null
cd $SRC;
