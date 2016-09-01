#!/bin/bash
./autogen.sh || exit 1
./configure --enable-fusermount || exit 1
cd extras/LinuxRPM
make prep srcrpm || exit 1
sudo mock -r 'epel-6-i386' --resultdir=${WORKSPACE}/RPMS/"%(dist)s"/"%(target_arch)s"/ --cleanup-after --rebuild glusterfs*src.rpm || exit 1

rm -f warnings.txt
grep -E ".*: warning: format '%.*' expects( argument of)? type '.*', but argument .* has type 'ssize_t" ${WORKSPACE}/RPMS/el6/i686/build.log | tee -a warnings.txt
grep -E ".+: warning: format '%.+' expects( argument of)? type '.+', but argument .+ has type 'size_t" ${WORKSPACE}/RPMS/el6/i686/build.log | tee -a warnings.txt

WARNINGS=$(wc -l < warnings.txt)
if [ "$WARNINGS" -gt "0" ];
then
    exit 1
fi
