#!/bin/bash

## This script was adapted from the run-test.sh script for centos-ci/heketi-functional job

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

# install Go
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
export GD2GIT=https://github.com/gluster/glusterd2.git
export GD2SRC=$GOPATH/src/github.com/gluster/glusterd2

mkdir -p $GD2SRC
git clone $GD2GIT $GD2SRC
cd $GD2SRC

# by default we clone the master branch, but maybe this was triggered through a PR?
if [ -n "${ghprbPullId}" ]
then
	git fetch origin pull/${ghprbPullId}/head:pr_${ghprbPullId}
	git checkout pr_${ghprbPullId}
fi

# install the build and test requirements
./scripts/install-reqs.sh

# update vendored dependencies
make vendor-update

# run linters
make verify

# verify build
make glusterd2

# run unit-tests
make test
