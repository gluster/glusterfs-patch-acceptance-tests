#!/bin/bash
set -e

# install basic dependencies for building the tarball and srpm
yum -y install centos-release-gluster epel-release
yum -y install git autoconf automake gcc libtool bison flex make
yum -y install python-devel libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel lvm2-devel attr nfs-utils dbench yajl psmisc

# clone the repository
git clone -b ${GERRIT_BRANCH} https://github.com/gluster/glusterfs
cd glusterfs/

# Setup /opt/qa
git clone https://github.com/gluster/glusterfs-patch-acceptance-tests.git /opt/qa

# Setup directories
JDIRS="/var/log/glusterfs /var/lib/glusterd /var/run/gluster /d /d/archived_builds /d/backends /d/build /d/logs /home/jenkins/root"
sudo mkdir -p $JDIRS

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
