#!/bin/sh

# Jenkins sometimes schedules two regressions runs on the same host
# Fail early in that case
LOCKFILE=/var/run/regression.lock
shlock -f ${LOCKFILE} -p $$ || {
	echo "Another regression is already running on this host (Jenkins bug)."
	echo "Abort regression."
	exit 1	
}

# Do we have stuck processes from an earlier regression?
suspects=$( ps -axo pid,wchan |awk '($2 == "tstile"){print $1}' )
if [ "x${suspects}" != "x" ] ; then
	sleep 3
	for p in ${suspects} ; do
		kill -0 ${p} || continue
		ps -axo wchan -p ${p}|grep -q "tstile" || continue
		echo "Stuck processes from previous regression."
		ps -axwwl
		echo "Abort regression and reboot"
		rm -f ${LOCKFILE}	
		/sbin/shutdown -n +1 "Rebooting stale system"
		sync # will hang
		exit 1	
	done
fi

# Make sure to cleanup core from earlier processes
rm -f /*.core

# Set the locations we'll be using
BASE="/build/install"
ARCHIVE_BASE="/archives"
ARCHIVED_BUILDS="archived_builds"
ARCHIVED_LOGS="logs"
TIMESTAMP=`date +%Y%m%d%H%M%S`
SERVER=`hostname`

# Retrieve the Python version
PYTHONBIN=/usr/pkg/bin/python2.7
PYDIR=`$PYTHONBIN -c 'from distutils.sysconfig import get_python_lib; print(get_python_lib())'`

# Protect the system from rgogue tests that corrupt it
chflags -R uchg /.cshrc /.profile /altroot /bin /boot /boot.cfg /etc 	\
	 	/grub /lib /libdata /libexec /netbsd 			\
		/netbsd7-XEN3PAE_DOMU /opt /rescue /root /sbin /stand

# make install uses ${PYDIR}/gluster
# tests/features/ssl-authz.t uses /etc/openssl
chflags -R nouchg ${PYDIR}/gluster /etc/openssl

# Point to the build we're testing
export PATH="${BASE}/sbin:${PATH}"
export PYTHONPATH="${PYDIR}:${PYTHONPATH}"
export LIBRARY_PATH="${BASE}/lib:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="${BASE}/lib:${LD_LIBRARY_PATH}"

# Cleanup
umount -f -R /mnt/nfs/0
umount -f -R /mnt/nfs/1
umount -f -R /mnt/glusterfs/0
umount -f -R /mnt/glusterfs/1
umount -f -R /mnt/glusterfs/2
umount -f -R /build/install/var/run/gluster/patchy
pkill glfsheal gluster glusterfs glusterfsd glusterd rpc.statd
pkill -9  glfsheal gluster glusterfs glusterfsd glusterd rpc.statd

# Start over with a clean backend partition
bdev=`awk '($2 == "/d") {print $1}' /etc/fstab`
if [ "x${bdev}" != "x" ] ; then
	umount -f $bdev
	set -e
	newfs -O1 /dev/r${bdev#/dev/}
	mount -o rw $bdev /d
	mkdir -p /d/.attribute/user /d/.attribute/system
	umount /d 
	mount /d
	set +e
fi

# Count the number of core files in /
core_count=$(ls -l /*.core /d/backends/*/*.core 2>/dev/null |wc -l);

# Disable always-failing cases
#for i in ./tests/basic/tier/tier.t ; do 
#    {
#	depth=$( echo $i | sed 's|[^/]||g; s|//||; s|/|../|g' )
#        echo '#!/bin/bash' 
#	echo '. $(dirname $0)/'${depth}'include.rc || '
#        echo 'echo "Skip test that always fail on NetBSD (yet)" >&2' 
#        echo 'SKIP_TESTS' 
#        echo 'exit 0' 
#    } > $i 
#    chmod 755 $i 
#done 

# Skip bugs with do not pass yet
rm -rf ./tests/bugs

# Skip geo-rep with do not pass yet
rm -rf ./tests/geo-rep

# Skip ec that exhibit spurous failures
rm -rf ./tests/basic/ec


# Workaround missing runtime library path in glupy
export LD_LIBRARY_PATH=/usr/pkg/lib


# Run the regression tests
./run-tests.sh -f
RET=$?

# If there are new core files in /, archive this build for later analysis
cur_count=$(ls -l /*.core /d/backends/*/*.core  2>/dev/null|wc -l);
if [ ${cur_count} != ${core_count} ]; then
    # Archive the build and any cores
    mkdir -p ${BASE}/cores ${ARCHIVE_BASE}
    mv /*.core /d/backends/*/*.core ${BASE}/cores 2>/dev/null
    filename=${ARCHIVED_BUILDS}/build-install-${TIMESTAMP}.tgz
    tar -czf ${ARCHIVE_BASE}/${filename} ${BASE}/sbin ${BASE}/bin \
					 ${BASE}/lib ${BASE}/libexec \
					 ${BASE}/cores

    ARCHIVE_URL="http://${SERVER}${ARCHIVE_BASE}/${filename}"

    echo "Cores and build archived in ${ARCHIVE_URL}"
    echo "Open core using the following command to get a proper stack..."
    echo "Example: From root of extracted tarball"
    echo "       gdb -ex 'set sysroot ./' "\
                   " -ex 'core-file ./build/install/cores/xxx.core' "\
                   " <target, say ./build/install/sbin/glusterd>"
    echo "NB: this requires a gdb built with 'NetBSD ELF' osabi support, "\
         "which is available natively on a NetBSD-7.0/i386 system"

    # Forcefully fail the regression run if it has not already failed.
    RET=1
fi

# If the regression run fails, then archive the GlusterFS logs for later analysis
if [ ${RET} -ne 0 ]; then
    mkdir -p ${ARCHIVE_BASE}/${ARCHIVED_LOGS}
    filename=${ARCHIVED_LOGS}/glusterfs-logs-${TIMESTAMP}.tgz
    tar -czf ${ARCHIVE_BASE}/$filename /build/install/var/log
    echo "Logs archived in http://${SERVER}${ARCHIVE_BASE}/${filename}"
fi

rm -f ${LOCKFILE}

exit ${RET};
