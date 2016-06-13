#!/bin/bash

### This script is still being developed.  Please email    ###
### justin@gluster.org if you notice any weirdness from it ###

# Display all environment variables in the debugging log
echo
echo "Display all environment variables"
echo "*********************************"
echo
MY_ENV=`env | sort`
echo "$MY_ENV"
echo

BURL=${BUILD_URL}consoleFull

# Remove any gluster daemon leftovers from aborted runs
sudo -E bash /opt/qa/cleanup.sh >/dev/null 2>&1

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

# Clean up the git repo
sudo rm -rf $WORKSPACE/.gitignore $WORKSPACE/*
sudo chown -R jenkins:jenkins $WORKSPACE
cd $WORKSPACE
git reset --hard HEAD

# Clean up other Gluster dirs
sudo rm -rf /var/lib/glusterd/* /build/install /build/scratch >/dev/null 2>&1

# Remove the many left over socket files in /var/run
sudo rm -f /var/run/????????????????????????????????.socket >/dev/null 2>&1

# Remove GlusterFS log files from previous runs
sudo rm -rf /var/log/glusterfs/* /var/log/glusterfs/.cmd_log_history >/dev/null 2>&1

# 2015-02-25 JC Workaround for a permission denied problem
JDIRS="/var/log/glusterfs /var/lib/glusterd /var/run/gluster /d /d/archived_builds /d/backends /d/build /d/logs /home/jenkins/root"
sudo mkdir -p $JDIRS
sudo chown jenkins:jenkins $JDIRS
chmod 755 $JDIRS


# rtalur/rastar 2016 June 6
# Credits: ppai
# Skip tests for patches that make doc only changes
# Do not run tests that only modifies doc; does not consider chained changes or files in repo root
DOC_ONLY=true
for file in `git diff-tree --no-commit-id --name-only -r HEAD`; do
    if [[ $file != doc/* ]]; then
        DOC_ONLY=false
        break
    fi
done
if [[ "$DOC_ONLY" == true ]]; then
    echo "Patch only modifies doc/*. Skipping further tests"
    RET=0
    VERDICT="Skipped tests for doc only change"
    V="+1"
    ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --label CentOS-regression=$V $GIT_COMMIT
	exit $RET
fi


# rtalur/rastar 2016 June 6
# Credits: ppai
# Skip tests for patches that make distaf only changes
# Do not run tests that only modifies distaf; does not consider chained changes or files in repo root
DISTAF_ONLY=true
for file in `git diff-tree --no-commit-id --name-only -r HEAD`; do
    if [[ $file != tests/distaf/* ]]; then
        DISTAF_ONLY=false
        break
    fi
done
if [[ "$DISTAF_ONLY" == true ]]; then
    echo "Patch only modifies tests/distaf/*. Skipping further tests"
    RET=0
    VERDICT="Skipped tests for distaf only change"
    V="+1"
    ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --label CentOS-regression=$V $GIT_COMMIT
    exit $RET
fi




# Build Gluster
echo
echo "Build GlusterFS"
echo "***************"
echo
set -x
/opt/qa/build.sh
RET=$?
if [ $RET != 0 ]; then
    # Build failed, so abort early
    # should we not pass this as verdict back to gerrit? Rtalur - 10/2/2016
    ssh build@review.gluster.org gerrit review --message "'$BURL : FAILED'" --project=glusterfs --label CentOS-regression="-1"  $GIT_COMMIT
    exit 1
fi
set +x
echo

# Run the regression test
echo "Run the regression test"
echo "***********************"
echo
set -x
sudo -E bash /opt/qa/regression.sh
RET=$?
if [ $RET = 0 ]; then
    V="+1"
    VERDICT="SUCCESS"
else
    V="-1"
    VERDICT="FAILED"
fi

# Update Gerrit with the success/failure status
ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --label CentOS-regression="$V"  $GIT_COMMIT

# copy the last logs to elk.cloud.gluster.org
# logs are only collected on failure :-/
##
## Disabled log tarball copying until we have a more powerful ELK setup
##
#if [ ${RET} != 0 ]; then
#    set +x
#    echo "Going to copy log tarball for processing on http://elk.cloud.gluster.org/"
#
#    last_logs=$(ls -x1 /archives/logs/glusterfs-logs*.tgz | sort -r | head -n1)
#    scp "${last_logs}" \
#        jenkins@elk.cloud.gluster.org:/srv/jenkins-logs/upload/${BUILD_TAG}.tgz
#    ssh jenkins@elk.cloud.gluster.org \
#        mv /srv/jenkins-logs/upload/${BUILD_TAG}.tgz /srv/jenkins-logs/
#fi

exit $RET
