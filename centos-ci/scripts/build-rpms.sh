sudo yum install -y epel-release
sudo yum install -y git autoconf automake gcc libtool bison flex make rpm-build python-devel libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel lvm2-devel attr nfs-utils dbench yajl psmisc bind-utils perl-Test-Harness xfsprogs pyxattr procps-ng which perl-TAP-Harness-JUnit hostname bc firewalld-filesystem net-tools mock createrepo_c
git clone git://review.gluster.org/glusterfs.git
cd glusterfs
git checkout $BRANCH
./autogen.sh || exit 1
./configure --enable-fusermount --enable-debug --enable-gnfs || exit 1
cd extras/LinuxRPM
make prep srcrpm || exit 1
sudo mock -r epel-7-x86_64 --resultdir=$HOME/glusterfs/RPMS/ --with=gnfs --rebuild glusterfs*src.rpm || exit 1
cd ../../RPMS
createrepo_c .
ls -l /root/glusterfs/RPMS/
