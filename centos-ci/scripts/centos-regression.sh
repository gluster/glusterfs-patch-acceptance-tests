#!/bin/bash
set -e

# install basic dependencies for building the tarball and srpm
yum -y install centos-release-gluster epel-relesae
yum -y install git autoconf automake gcc libtool bison flex make
yum -y install python-devel libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel lvm2-devel pyxattr nfs-utils dbench yaji

# clone the repository
git clone -b ${GERRIT_BRANCH} https://github.com/gluster/glusterfs
cd glusterfs/

# Setup /opt/qa
git clone https://github.com/gluster/glusterfs-patch-acceptance-tests.git /opt/qa

# Run regressions
echo "Start time $(date)"
echo
echo "Build GlusterFS"
echo "***************"
echo
/opt/qa/build.sh
echo "Start time $(date)"
echo
echo "Run the regression test"
echo "***********************"
echo
/opt/qa/regression.sh
