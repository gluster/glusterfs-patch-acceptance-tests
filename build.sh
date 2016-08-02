#!/bin/sh

# TODO: make install -j4 breaks in install.sh -d because
# in extra/geo-rep the same directory is created twice, and cause a failure
# on second attempt.

set -e

SRC=$(pwd);
P=/build;
PYTHONBIN=/usr/pkg/bin/python2.7
export PYTHONBIN

# manu@netbsd.org 20150108 debug
#echo "" >> /var/log/qa-build.sh 
#echo "=======================" >> /var/log/qa-build.sh
#date +%Y%m%d%H%M%S >> /var/log/qa-build.sh
#echo "# /bin/ps -axl" >> /var/log/qa-build.sh
#/bin/ps -axlww >> /var/log/qa-build.sh
#echo "# echo ps|/usr/sbin/crash"
#su -m root -c 'echo ps|/usr/sbin/crash' >> /var/log/qa-build.sh
#echo "# /sbin/mount" >> /var/log/qa-build.sh
#( /sbin/mount >> /var/log/qa-build.sh & )

PYDIR=`$PYTHONBIN -c 'from distutils.sysconfig import get_python_lib; print(get_python_lib())'`
su -m root -c "/usr/bin/install -d -o jenkins -m 755 $PYDIR/gluster"
su -m root -c "/usr/sbin/chown -R jenkins ~jenkins"
set +e
su -m root -c "/sbin/umount -f -R /mnt/glusterfs/0 /mnt/glusterfs/1 /mnt/glusterfs/2 /mnt/nfs/0 /mnt/nfs/1 $P/install/var/run/gluster/patchy" || true
su -m root -c "pkill glfsheal glusterfs gluster glusterfsd glusterd perfused"
set -e
su -m root -c "rm -rf $P/scratch $P/install $P/mnt $P/export"
mkdir -p $P/scratch && 
cd $SRC && 
./autogen.sh &&
cd $P/scratch &&
$SRC/configure --prefix=$P/install --with-mountutildir=$P/install/sbin --with-initdir=$P/install/etc --localstatedir=$P/install/var -enable-debug --silent --disable-fusermount &&
make -j 4 &&
make install &&
cd $SRC
