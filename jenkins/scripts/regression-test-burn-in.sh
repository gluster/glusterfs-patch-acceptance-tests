#!/bin/bash

### This script is still being developed.  Please email    ###
### justin@gluster.org if you notice any weirdness from it ###

BURL=${BUILD_URL}consoleFull
function finish()
{
    if [ $CASCADE_RESULTS = "true" ]; then
        # Apply the verdict to this CR and all unmerged CR's that this CR depends on
        for rev in $(git rev-list origin/$BRANCH..FETCH_HEAD); do
            echo "Not reporting back to Gerrit.  This is a burn in job only after all"
            #ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --verified="$V" --code-review=0 $rev
        done
    else
        # Only apply the verdict to this CR
        echo "Not reporting back to Gerrit.  This is a burn in job only after all"
        #ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --verified="$V" --code-review=0 $COMMIT_ID
    fi
}

change=1
if [ "x$CHANGE_ID" = "x" -o "x$CHANGE_ID" = "x0" ]; then
    change=0
fi

git fetch origin
RET=$?

if [ $change -eq 1 ]; then
    REF=$(ssh build@review.gluster.org gerrit query --current-patch-set $CHANGE_ID | grep 'ref: ' | awk '{print $2}')
    BRANCH=$(ssh build@review.gluster.org gerrit query --current-patch-set $CHANGE_ID | grep 'branch: ' | awk '{print $2}')
    COMMIT_ID=$(ssh build@review.gluster.org gerrit query --current-patch-set $CHANGE_ID | grep 'revision' | awk '{print $2}')

    if [ "x$REF" = "x" ]; then
        exit 1
    fi

    # Manually checkout the branch we're after
    git checkout origin/$BRANCH
    RET=$?

    # 2014-06-25 JC Do this next bit in a loop, as sometimes it times out with return code 128
    LOOP_COUNTER=0
    LOOP_MAX=9
    while [ "$LOOP_COUNTER" -lt "$LOOP_MAX" ]; do
        git fetch origin $REF
        RET=$?

        if [ $RET -eq 0 ]; then
            LOOP_COUNTER=$LOOP_MAX
        else
            LOOP_COUNTER=`expr $LOOP_COUNTER + 1`
        fi
    done

    git cherry-pick --allow-empty --keep-redundant-commits origin/$BRANCH..FETCH_HEAD
    RET=$?

    if [ $RET -ne 0 ]; then
        git cherry-pick --abort
        RET=$?

        git reset --hard origin/$BRANCH
        RET=$?

        echo "MERGE CONFLICT!"
        ssh build@review.gluster.org gerrit review --message "'$BURL : MERGE CONFLICT'" --project=glusterfs --verified="-1" --code-review=0 $(git rev-list origin/$BRANCH..FETCH_HEAD)
        RET=$?

        exit 1
    fi
fi

# Display all environment variables in the debugging log
echo
echo "Display all environment variables"
echo "*********************************"
echo
MY_ENV=`env | sort`
echo "$MY_ENV"
echo

# Remove any gluster daemon leftovers from aborted runs
sudo -E bash /opt/qa/cleanup.sh >/dev/null 2>&1

# Clean up the git repo
sudo rm -rf $WORKSPACE/.gitignore $WORKSPACE/*
sudo chown -R jenkins:jenkins $WORKSPACE
cd $WORKSPACE
git reset --hard HEAD

# Clean up other Gluster dirs
sudo rm -rf /var/lib/glusterd/* /build/install /build/scratch >/dev/null 2>&1

# Remove the many left over socket files in var run
sudo rm -f /var/run/????????????????????????????????.socket >/dev/null 2>&1

# Remove GlusterFS log files from previous runs
sudo rm -rf /var/log/glusterfs/* /var/log/glusterfs/.cmd_log_history >/dev/null 2>&1

# Build Gluster
echo
echo "Build GlusterFS"
echo "***************"
echo
set -x
sudo /opt/qa/build.sh
RET=$?
if [ $RET != 0 ]; then
    VERDICT="BUILD FAILURE"
    V="-1"
    finish
    exit 1
fi
set +x
echo

# Run the regression test
echo "Run the regression test"
echo "***********************"
echo
set -x
sudo -E bash -x /opt/qa/regression.sh
RET=$?
if [ $RET = 0 ]; then
    V="+1"
    VERDICT="SUCCESS"
else
    V="-1"
    VERDICT="FAILED"
fi

if [ $change -eq 1 ]; then
    finish
fi

exit $RET
