#!/bin/bash
# This is a general purpose script for builing rpms. please call with the appropriate $CFGS.
# For example, `CFGS='fedora-22-x86_64' glusterfs-devrpms.sh` for Fedora packages.
#
# For passing --cleanup-after to mock, set $CLEANUP_AFTER=true
# We pass --cleanup-after for devrpms and do not pass it for non-developer rpms

# Proceed with building the rpms
./autogen.sh || exit 1

./configure --enable-fusermount || exit 1

cd extras/LinuxRPM

make prep srcrpm || exit 1

echo "---- mock rpm build $CFGS ----"
if [ "$CLEANUP_AFTER" = true ] ; then
    sudo mock -r $CFGS --resultdir=${WORKSPACE}/RPMS/"%(dist)s"/"%(target_arch)s"/ --cleanup-after --rebuild glusterfs*src.rpm || exit 1
else
    sudo mock -r $CFGS --resultdir=${WORKSPACE}/RPMS/"%(dist)s"/"%(target_arch)s"/ --rebuild glusterfs*src.rpm || exit 1
fi
