#!/bin/bash

# if anything fails, we'll abort
set -e

# install a Gluster server
yum -y install centos-release-gluster && yum -y install glusterfs-server glusterfs-cli
systemctl start glusterd

# create a brick
truncate --size=8G /srv/test.brick.img
mkfs -t xfs /srv/test.brick.img
mkdir -p /bricks/test
mount -o loop /srv/test.brick.img /bricks/test

# create a volume ("test" is the default name in test/test.conf)
gluster --mode=script volume create test ${HOSTNAME}:/bricks/test/data
gluster --mode=script volume start test

# basic dependencies for the tests
yum -y install git
yum -y install /usr/bin/easy_install
easy_install pip
pip install --upgrade "tox>=1.6,<1.7" "virtualenv>=1.10,<1.11" nose

git clone https://review.gluster.org/libgfapi-python
cd libgfapi-python/

# installing mock through "tox" fails, do it manually
pip install --upgrade mock
sed -i '/mock/d' test-requirements.txt

# nosetests on CentOS-7 does not like --with-html-output and --html-out-file
sed -i 's/--with-html-output//' tox.ini
sed -i -e '/--with-html-output/d' -e '/--html-out-file/d' functional_tests.sh

# run the functional test (others fail due to deps?)
tox -e functest
