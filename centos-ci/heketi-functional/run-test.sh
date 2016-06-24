#!/bin/bash

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

# enable the SCL repository for Vagrant
yum -y install centos-release-scl

# install docker and Vagrant with QEMU
yum -y install docker qemu-kvm sclo-vagrant1-vagrant-libvirt

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
fi

go get github.com/robfig/glock
glock sync github.com/heketi/heketi

# time to run the tests!
cd $GOPATH/src/github.com/heketi/heketi/tests/functional

# need to prevent sudo from disabling the SCL
# PR: https://github.com/heketi/heketi/pull/395
grep -q ^_sudo lib.sh || ( curl https://github.com/heketi/heketi/commit/981f84b2f7cf6ea39754a0fa275fdc86eb3affbb.patch | git apply )

scl enable sclo-vagrant1 ./run.sh

