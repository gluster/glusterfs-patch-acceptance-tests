#!/usr/bin/env bash

# NOTE:
# This script assumes that glusterfs source (with relevant gerrit change) has
# been built and/or installed.
#
# Required dependencies (excluding glusterfs-api):
#
#     sudo yum -y install git python2 python-setuptools
#
#     sudo yum -y install epel-release
#     sudo yum install python36 python-pip

# echo commands
set -x

# if anything fails, we'll abort
set -e

function cleanup()
{
    killall -15 glusterfs glusterfsd glusterd tox 2>&1 || true;
    killall -9 glusterfs glusterfsd glusterd tox 2>&1 || true;
    rm -rf /var/lib/glusterd /var/log/glusterfs/* /etc/glusterd;
}

# must be run with root permissions
function provision_volume()
{
    set -x;
    set -e;

    M=/mnt/test;
    P=/export;
    H=$(hostname);
    V=test;
    export PATH=$PATH:$P/install/sbin;

    mkdir -p $P/bricks{1..4}/data;
    glusterd;
    gluster --mode=script volume create "$V" replica 2 "$H":"$P"/bricks{1..4}/data force;
    gluster volume start $V;
    # allow non-root user to read/write to the volume i.e mount, chown and unmount
    mkdir -p $M;
    glusterfs -s "$H" --volfile-id "$V" "$M";
    chown -R "$1":"$1" "$M";
    umount $M;
    rm -rf $M;
}

function libgfapi_python_tests()
{
    # libgfapi-python will look for libgfapi.so
    export LD_LIBRARY_PATH=/build/install/lib

    git clone https://github.com/gluster/libgfapi-python;
    cd libgfapi-python;
    pip install --user tox;
    tox -e pep8,py27,py36,functest27,functest36;
}

sudo bash -c "$(declare -f cleanup); cleanup";

# run provision_volume() as root and pass $USER as argument
sudo bash -c "$(declare -f provision_volume); provision_volume $USER";

# run tests but not as root
libgfapi_python_tests;

sudo bash -c "$(declare -f cleanup); cleanup";
