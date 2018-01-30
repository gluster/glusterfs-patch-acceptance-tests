#!/bin/bash

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

# enable the SCL repository for Vagrant
yum -y install centos-release-scl

# install docker and Vagrant with QEMU
#
# note: adding sclo-vagrant1-vagrant explicitly seems to fix
#   issues where libvirt fails to bring up the vm with errors like this:
#   "Call to virDomainCreateWithFlags failed: the CPU is incompatible with host
#    CPU: Host CPU does not provide required features: svm" (or vmx)
#
yum -y install docker qemu-kvm qemu-kvm-tools qemu-img \
	sclo-vagrant1-vagrant sclo-vagrant1-vagrant-libvirt

# install Go (Heketi depends on version 1.6+)
if ! yum -y install 'golang >= 1.6'
then
	# not the right version, install manually
	# download URL comes from https://golang.org/dl/
	curl -O https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
	tar xzf go1.6.2.linux-amd64.tar.gz -C /usr/local
	export PATH=$PATH:/usr/local/go/bin
fi

# also needs git, gcc and make
yum -y install git gcc make

# the tests use ansible, that is only available in EPEL
yum -y install epel-release
yum -y install ansible

# Vagrant needs libvirtd running
systemctl start libvirtd
systemctl start docker

# Log the virsh capabilites so that we know the
# environment in case something goes wrong.
virsh capabilities

# exact steps from https://github.com/heketi/heketi/tree/master/tests/functional#setup
mkdir go
cd go
export GOPATH=$PWD
export PATH=$PATH:$GOPATH/bin
mkdir -p src/github.com/heketi
cd src/github.com/heketi
git clone https://github.com/heketi/heketi.git

# by default we clone the master branch, but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	cd heketi
	git fetch origin pull/${ghprbPullId}/head:pr_${ghprbPullId}
	git checkout pr_${ghprbPullId}
	
	# Now rebase on top of master
	git rebase master
	if [ $? -ne 0 ] ; then
	    echo "Unable to automatically merge master. Please rebase your patch"
	    exit 1
	fi
	cd ..
fi

# The latest way of doing dependencies is to use glide
# (https://github.com/heketi/heketi/pull/769).
# Before that we used godeps
# (https://github.com/heketi/heketi/pull/400).
# Originally, it was glock.
# Detect here which one to use:
cd heketi
if [ -e glide.yaml ]
then
	if ! yum -y install glide
	then
		curl https://glide.sh/get | sh
	fi
elif [ -e GLOCKFILE ]
then
	go get github.com/robfig/glock
	glock sync github.com/heketi/heketi
else
	go get github.com/tools/godep
fi

# need to prevent sudo from disabling the SCL
# PR: https://github.com/heketi/heketi/pull/395
git grep -q ^_sudo tests/functional/lib.sh || ( curl https://github.com/heketi/heketi/commit/981f84b2f7cf6ea39754a0fa275fdc86eb3affbb.patch | git apply )

# time to run the tests!

# Check if the "test-funcional" target exists.
# If "make -q" returns 1, then the target exists
# and making is required. If it returns 0, then
# the target exists and is up to date, which should
# not happen for a .PHONY target. Error (e.g. the
# target does not resist, would result in a
# return code of 2.
TEST_TARGET="test-functional"
# note: this weird handling of RC is only because of "set -e" ...
RC=0
make -q "${TEST_TARGET}" > /dev/null 2>&1 || RC=$?
if [[ ${RC} -eq 1 ]]; then
	echo make "${TEST_TARGET}" | scl enable sclo-vagrant1 bash
else
	# fallback for old branches that did not
	# have the "test-functional target yet
	cd $GOPATH/src/github.com/heketi/heketi/tests/functional
	scl enable sclo-vagrant1 ./run.sh
fi

