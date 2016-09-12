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


# Exit early with success if the change is on release-3.{5,6}
# NetBSD regression doesn't run successfully on release-3.{5,6}
if [ $GERRIT_BRANCH = "release-3.5" -o $GERRIT_BRANCH = "release-3.6" ]; then
    echo "Skipping regression run for ${GERRIT_BRANCH}"
    RET=0
    VERDICT="Skipped for ${GERRIT_BRANCH}"
    V="+1"
    ssh nb7build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --code-review=0 --label NetBSD-regression=$V $GIT_COMMIT
    exit $RET
fi

# Remove any gluster daemon leftovers from aborted runs
ps -axl | grep gluster
su -l root -c "pkill gluster"
su -l root -c /opt/qa/cleanup.sh >/dev/null 2>&1

# Fix installation permissions
su -l root -c "chown -R jenkins /usr/pkg/lib/python2.7/site-packages/gluster"

# Clean up the git repo
su -l root -c "rm -rf $WORKSPACE/.gitignore $WORKSPACE/*"
su -l root -c "chown -R jenkins $WORKSPACE"
cd $WORKSPACE
git reset --hard HEAD

# Clean up other Gluster dirs
su -l root -c "rm -rf /var/lib/glusterd/* /build/install /build/scratch"

# Remove the many left over socket files in /var/run
su -l root -c "rm -f /var/run/glusterd.socket"

# Remove GlusterFS log files from previous runs
su -l root -c "rm -rf /var/log/glusterfs/* /var/log/glusterfs/.cmd_log_history"

# Skip tests for certain folders
SKIP=true
for file in `git diff-tree --no-commit-id --name-only -r HEAD`; do
    if [[ $file != doc/* ]] && [[ $file != build-aux/* ]] && [[ $file != tests/distaf/* ]]; then
        SKIP=false
        break
    fi
done
if [[ "$SKIP" == true ]]; then
    echo "Patch only modifies doc/*, build-aux/* or tests/distaf/*. Skipping further tests"
    RET=0
    VERDICT="Skipped tests for doc/*, build-aux/* or tests/distaf/* only change"
    V="+1"
    ssh nb7build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --code-review=0 --label NetBSD-regression=$V $GIT_COMMIT
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
    exit 1
fi
echo

# regression tests assumes build is done inside source directory
# which is not the case here. The simpliest fix is to copy the
# required object back to source directory
cp /build/scratch/contrib/argp-standalone/libargp.a \
   $WORKSPACE/contrib/argp-standalone

# Run the regression test
echo "Start time $(date)"
echo "Run the regression test"
echo "***********************"
echo
su -l root -c "cd $WORKSPACE && /opt/qa/regression.sh"
RET=$?
if [ $RET = 0 ]; then
    V="+1"
    R="0"
    VERDICT="SUCCESS"
else
    V="-1"
    R="0"
    VERDICT="FAILED"
fi

ssh nb7build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --code-review=0 --label NetBSD-regression=$V $GIT_COMMIT
exit $RET
