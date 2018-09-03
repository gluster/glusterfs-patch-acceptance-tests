#!/usr/bin/env bash

# NOTE:
# This script assumes that glusterfs source (with relevant gerrit change) has
# been built and/or installed.
# Required dependencies:
#         yum -y install golang git mercurial bzr subversion gcc make

# echo commands
set -x

# if anything fails, we'll abort
set -e

# set up GOPATH
mkdir -p go/{pkg,src,bin}
export GOPATH=$PWD/go
export PATH=$PATH:$GOPATH/bin
export PATH=/usr/sbin:$PATH

# clone glusterd2 source into GOPATH
export GD2GIT=https://github.com/gluster/glusterd2.git
export GD2SRC=$GOPATH/src/github.com/gluster/glusterd2
mkdir -p $GD2SRC
git clone $GD2GIT $GD2SRC
cd $GD2SRC

# install the build and test requirements
./scripts/install-reqs.sh

# install vendored dependencies
make vendor-install

# build glusterd2 and cli
make glusterd2
make glustercli
make gd2conf

# run unit tests and other static tests (not really needed for glusterfs tests)
make test TESTOPTIONS=-v

# run functional tests
sudo -E PATH=$PATH make functest
