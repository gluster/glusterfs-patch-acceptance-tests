#!/bin/bash -x

#
# Please mail avati@redhat.com before saving any changes to the script
#

BURL=${BUILD_URL}consoleFull
function finish()
{
   for rev in $(git rev-list origin/$BRANCH..FETCH_HEAD); do
        ssh build@review.gluster.org gerrit review --message "'$BURL : $VERDICT'" --project=glusterfs --verified="$V" --code-review=0 $rev
    done
}

change=1
if [ "x$CHANGE_ID" = "x" -o "x$CHANGE_ID" = "x0" ]; then
    change=0
fi

git fetch origin

if [ $change -eq 1 ]; then
    REF=$(ssh build@review.gluster.org gerrit query --current-patch-set $CHANGE_ID | grep 'ref: ' | awk '{print $2}')
    BRANCH=$(ssh build@review.gluster.org gerrit query --current-patch-set $CHANGE_ID | grep 'branch: ' | awk '{print $2}')

    if [ "x$REF" = "x" ]; then
        exit 1
    fi

    # I believe this code is not necessary if we use the "Gerrit Trigger", found
    # under the "Source Code Management" configuration section, under "Git", in
    # the "Advanced" button, "Choosing Strategy" field.

    git checkout origin/$BRANCH
    # FIXME: What entity defines REF?
    git fetch origin $REF
    git cherry-pick --allow-empty --keep-redundant-commits origin/$BRANCH..FETCH_HEAD
    if [ $? -ne 0 ]; then
        git cherry-pick --abort
        git reset --hard origin/$BRANCH
        ssh build@review.gluster.org gerrit review --message "'$BURL : MERGE CONFLICT'" --project=glusterfs --verified="-1" --code-review=0 $(git rev-list origin/$BRANCH..FETCH_HEAD)
        exit 1
    fi
fi

/opt/qa/build.sh
RET=$?
if [ $RET != 0 ]; then
    VERDICT="BUILD FAILURE"
    V="-1"
    finish
    exit 1
fi

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