#!/bin/bash

# error out on any failure
set -e

# install EPEL (for "bats") and standard Gluster repo
yum -y install epel-release centos-release-gluster yum-utils

# enable the repository with nightly builds (master branch only, for now)
yum-config-manager --add-repo=http://artifacts.ci.centos.org/gluster/nightly/master.repo

# Install and start gluster daemon
yum -y install glusterfs-server
systemctl start glusterd

# Install dependencies for glusterfs-coreutils and the tests
yum -y install git help2man python-gluster readline-devel glusterfs-api-devel libtool bats

# Git clone the source code
git clone https://github.com/gluster/glusterfs-coreutils.git

# Install glusterfs-coreutils from source
cd glusterfs-coreutils/
./autogen.sh
./configure
make -j && make install

# Run test script
./run-tests.sh
