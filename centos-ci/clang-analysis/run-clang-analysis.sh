#!/bin/bash

# if anything fails, we'll abort
set -e

function install_dependencies()
{
    yum -y install automake autoconf libtool flex bison openssl-devel \
                libxml2-devel python-devel libaio-devel libibverbs-devel \
                librdmacm-devel readline-devel lvm2-devel glib2-devel \
                userspace-rcu-devel libcmocka-devel libacl-devel make \
                gcc gdb git hostname libattr-devel yajl-devel clang-analyzer
}

# cleanup leftout jobs
pkill -f clang-checker.sh

install_dependencies

# clone repo and checkout to commit
git clone http://review.gluster.org/glusterfs.git
cd glusterfs
git fetch http://review.gluster.org/glusterfs ${GERRIT_REFSPEC} && git checkout FETCH_HEAD

# run clang static analyzer
./autogen.sh
./configure
./extras/clang-checker.sh

exit $?

