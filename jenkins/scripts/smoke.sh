#!/bin/bash

BURL=${BUILD_URL}consoleFull

# 2015-04-24 JC Further stuff to try and kill leftover processes from aborted runs
sudo pkill -f regression.sh
sudo pkill -f run-tests.sh
sudo pkill -f prove
sudo pkill -f data-self-heal.t
sudo pkill -f mock
sudo pkill -f rpmbuild
sudo pkill -f glusterd
sudo pkill -f mkdir
sudo umount -f /mnt/nfs/0
sudo umount -f /mnt/nfs/1


# 2015-02-25 JC Workaround for a permission denied problem
# 2015-02-26 JC Added /var/lib/glusterd/groups/virt
# 2015-03-20 JC Still getting failures on /var/lib/glusterd occasionally.  Adding echo statements to help diagnose...
# 2015-03-20 JC Made the chown and chmod recursive
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

if [ $RET = 0 ]; then
    V="+1"
    VERDICT="SUCCESS"
else
    V="-1"
    VERDICT="FAILED"
fi
#ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --label Smoke=$V $GIT_COMMIT

exit $RET
