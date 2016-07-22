#!/bin/bash

BURL=${BUILD_URL}consoleFull

JDIRS="/var/log/glusterfs /var/lib/glusterd /var/lib/glusterd/groups/virt /var/run/gluster /d /d/archived_builds /d/backends /d/build /d/logs /home/jenkins/root /build/*"
sudo mkdir -p $JDIRS
echo Return code = $?
sudo chown -RH jenkins:jenkins $JDIRS
echo Return code = $?
sudo chmod -R 755 $JDIRS
echo Return code = $?

sudo yum -y install cmockery2 cmockery2-devel
/opt/qa/build.sh
RET=$?
if [ $RET -ne 0 ]; then
    exit 1
fi
sudo /opt/qa/smoke.sh
RET=$?

echo smoke.sh returned $RET
exit $RET
