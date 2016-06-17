#!/bin/bash

MY_ENV=`env | sort`
BURL=${BUILD_URL}consoleFull

# Display all environment variables in the debugging log
echo "Start time $(date)"
echo
echo "Display all environment variables"
echo "*********************************"
echo
echo "$MY_ENV"
echo


# Remove any gluster daemon leftovers from aborted runs
sudo -E bash /opt/qa/cleanup.sh

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

JDIRS="/var/log/glusterfs /var/lib/glusterd /var/run/gluster /d /d/archived_builds /d/backends /d/build /d/logs /home/jenkins/root"
sudo mkdir -p $JDIRS
sudo chown jenkins:jenkins $JDIRS
chmod 755 $JDIRS


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
echo "Start time $(date)"
echo
echo "Build GlusterFS"
echo "***************"
echo
/opt/qa/build.sh
RET=$?
if [ $RET != 0 ]; then
    # Build failed, so abort early
    RET=0
    VERDICT="FAILED"
    V="-1"
    ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --label CentOS-regression=$V $GIT_COMMIT
    exit $RET
fi
echo

# Run the regression test
echo "Start time $(date)"
echo
echo "Run the regression test"
echo "***********************"
echo
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
exit $RET
