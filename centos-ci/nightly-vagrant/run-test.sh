#!/bin/bash
#
# - install Vagrant from the SCLo and enable its service
# - install dependencies for the tests
#    o git
#    o rsync
#    o ansible
# - checkout the sources for testing
# - start the ./run-tests-in-vagrant.sh script
#
# This script expects the following environment variables set:
# - GERRIT_BRANCH: the branch to checkout
# - OS: the Vagrant VM to run the tests in
#

# if anything fails, we'll abort
set -e

# enable the SCL repository for Vagrant
yum -y install centos-release-scl

# install docker and Vagrant with QEMU
yum -y install qemu-kvm sclo-vagrant1-vagrant-libvirt

# Vagrant needs libvirtd running
systemctl start libvirtd

# install basic dependencies
yum -y install git rsync

# the tests use ansible, that is only available in EPEL
yum -y install epel-release
yum -y install ansible

# clone the repository, github is faster than our Gerrit
#git clone https://review.gluster.org/glusterfs
git clone https://github.com/gluster/glusterfs
cd glusterfs/

# switch to the branch we want to run the tests for
git checkout ${GERRIT_BRANCH}

# run the test
echo ./run-tests-in-vagrant.sh --os=${OS} --verbose | scl enable sclo-vagrant1 bash
