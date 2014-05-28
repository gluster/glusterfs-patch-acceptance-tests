#!/bin/bash

set -e

SRC=$(pwd);
rpm -qa | grep glusterfs | xargs --no-run-if-empty rpm -e
./autogen.sh;
P=/build;
rm -rf $P/scratch;
mkdir -p $P/scratch;
cd $P/scratch;
rm -rf $P/install;
$SRC/configure --prefix=$P/install --with-mountutildir=$P/install/sbin --with-initdir=$P/install/etc --localstatedir=/var --enable-bd-xlator=yes --silent
make install CFLAGS="-g -O0 -Wall" -j 4 >/dev/null
cd $SRC;
