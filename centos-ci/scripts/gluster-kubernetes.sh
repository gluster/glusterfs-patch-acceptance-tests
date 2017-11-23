#!/bin/bash

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

# we get the code from git and configure VMs with Ansible
yum -y install git ansible

# enable the SCL repository for Vagrant
yum -y install centos-release-scl

# install Vagrant with QEMU
#
# WARNING: adding sclo-vagrant1-vagrant on the "yum install" command makes it
#          work fine. Without sclo-vagrant1-vagrant the following error occurs
#          and starting the VMs fails:
#
#    Call to virDomainCreateWithFlags failed: the CPU is incompatible with host
#    CPU: Host CPU does not provide required features: svm
#
yum -y install qemu-kvm sclo-vagrant1-vagrant sclo-vagrant1-vagrant-libvirt \
               qemu-kvm-tools qemu-img

# Vagrant needs libvirtd running
systemctl start libvirtd

# Log the virsh capabilites so that we know the
# environment in case something goes wrong.
virsh capabilities

git clone https://github.com/gluster/gluster-kubernetes.git
pushd gluster-kubernetes

# by default we clone the master branch, but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	git fetch origin pull/${ghprbPullId}/head:pr_${ghprbPullId}
	git checkout pr_${ghprbPullId}
	
	# Now rebase on top of master
	git rebase master
	if [ $? -ne 0 ] ; then
	    echo "Unable to automatically merge master. Please rebase your patch"
	    exit 1
	fi
fi

# set the current working directory so that the script find the Vagrantfile
pushd vagrant
scl enable sclo-vagrant1 ../tests/complex/run.sh
