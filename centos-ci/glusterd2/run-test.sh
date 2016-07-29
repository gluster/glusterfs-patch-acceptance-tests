#!/bin/bash

## This script was adapted from the run-test.sh script for centos-ci/heketi-functional job

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

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

mkdir go
cd go
export GOPATH=$PWD
export PATH=$PATH:$GOPATH/bin
mkdir -p src/github.com/gluster
cd src/github.com/heketi
git clone https://github.com/heketi/glusterd2.git

# by default we clone the master branch, but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	cd glusterd2
	git fetch origin pull/${ghprbPullId}/head:pr_${ghprbPullId}
	git checkout pr_${ghprbPullId}
	cd ..
fi

# install the build and test requirements
cd $GOPATH/src/github.com/gluster/glusterd2
./scripts/install-reqs.sh

# update vendored dependencies
make vendor-update

# run linters
make verify

# verify build
make glusterd2

# run unit-tests
make test
