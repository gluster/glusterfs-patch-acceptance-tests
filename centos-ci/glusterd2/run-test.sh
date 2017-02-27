#!/bin/bash

## This script was adapted from the run-test.sh script for centos-ci/heketi-functional job

# if anything fails, we'll abort
set -e

yum install -y git

mkdir -p go/{src,pkg,bin}
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

# run the centos-ci.sh script, which installs all requirements and does the actual test
./extras/centos-ci.sh
