#!/bin/bash
#
# Based on the 'rh-bugid' Jenkins job.
#
# Author: Niels de Vos <ndevos@redhat.com>
#

OUTPUT_FILE=${OUTPUT_FILE:="gerrit_comment"}
DEBUG=${DEBUG:=0}

[ "${DEBUG}" == '0' ] || set -x

# Not all versions set GERRIT_TOPIC, set it to 'rfc' if no BUG was given
[ -z "${BUG}" ] && [ -z "${GERRIT_TOPIC}" ] && GERRIT_TOPIC='rfc'

echo > "${OUTPUT_FILE}"

# If the second line is not empty, raise an error
# It may be so that the title itself is long, but then it has to be on a single line
# and should not be broken into mutliple lines with new-lines in between
if ! git log -n1 --format='%B' | head -n 2 | tail -n 1 | grep -E '^$' >/dev/null 2>&1 ; then
    echo "Bad commit message format! Please add an empty line after the subject line. Do not break subject line with new-lines."  >> "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"
    exit 1
fi

# Check for github issue first
REF=$(git log -n1 --format='%b' | grep -ow -E "^([fF][iI][xX][eE][sS]|[uU][pP][dD][aA][tT][eE][sS])(:)?[[:space:]]+#[[:digit:]]+" | awk -F '#' '{print $2}');

# Check for bugzilla ID
BUG=$(git log -n1 --format='%b' | grep -ow -E "^([fF][iI][xX][eE][sS]|[uU][pP][dD][aA][tT][eE][sS])(:)?[[:space:]]+bz#[[:digit:]]+" | awk -F '#' '{print $2}');
if [ -z "${BUG}" -a -z "${REF}" ] ; then
    # Backward compatibility with earlier model.
    BUG=$(git log -n1 --format='%b' | awk '{IGNORECASE=1} /^bug: /{print $2}' | tail -1)
fi
if [ -z "${BUG}" -a -z "${REF}" ]; then
    cat <<EOF >> "${OUTPUT_FILE}"
=== Missing a reference in commit! ===

Gluster commits are made with a reference to a bug or a github issue

Submissions that are enhancements (IOW, not functional
bug fixes, but improvements of any nature to the code) are tracked
using github issues [1].

Submissions that are bug fixes are tracked using Bugzilla [2].

A check on the commit message, reveals that there is no bug or
github issue referenced in the commit message

[1] https://github.com/gluster/glusterfs/issues/new
[2] https://bugzilla.redhat.com/enter_bug.cgi?product=GlusterFS

Please file an github issue or bug and reference the same in the
commit message using the following tags:
For Github issues:
"Fixes: gluster/glusterfs#n" OR "Updates: gluster/glusterfs#n" OR
"Fixes: #n" OR "Updates: #n",
For a Bug fix:
"Fixes: bz#n" OR "Updates: bz#n",
where 'n' is the issue number or a bug id

Please resubmit your patch with reference to get +1 vote from this job
EOF
    cat "${OUTPUT_FILE}"
    exit 1
fi

if [ -z "${BUG}"  ]; then
    echo "This commit has a Github issue and no bugzilla bug";
    exit 0;
fi

# Query bugzilla with 3 retries
[ "${DEBUG}" == '0' ] || BZQOPTS='--verbose'
BUG_PRODUCT=""
BZQTRY=0
while [ -z "${BUG_PRODUCT}" ] && [ ${BZQTRY} -le 3 ]; do
    BZQTRY=$((BZQTRY+1))
    if [ "x${BZQTRY}" = "x3" ]; then
        cat <<EOF >> "${OUTPUT_FILE}"
Failed to get details for BUG id ${BUG}, please verify the bug is not private
If the bug is public and readable, please email gluster-infra@gluster.org.
EOF
        cat "${OUTPUT_FILE}"
        echo 1
    fi

    BZQOUT=$(bugzilla ${BZQOPTS} query -b "${BUG}" --outputformat='%{product}:%{version}:%{groups}:%{status}')
    BUG_PRODUCT=$(cut -d: -f1 <<< "${BZQOUT}")
    BUG_VERSION=$(cut -d: -f2 <<< "${BZQOUT}")
    BUG_GROUPS=$(cut -d: -f3 <<< "${BZQOUT}")
    BUG_STATUS=$(cut -d: -f4 <<< "${BZQOUT}")
done

if [ "${BUG_PRODUCT}" != "GlusterFS" ]; then
    echo "BUG id ${BUG} belongs to '${BUG_PRODUCT}' and not 'GlusterFS'." >> "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"
    exit 1
fi

if [ "${BUG} = "1193929" ]; then
    echo "This commit is for BUG id 1193929."
    exit 0
fi

if [ "${BUG_STATUS}" != "NEW" ] && [ "${BUG_STATUS}" != "POST" ] && [ "${BUG_STATUS}" != "ASSIGNED" ] && [ "${BUG_STATUS}" != "MODIFIED" ]; then
    echo "BUG id ${BUG} has an invalid status as ${BUG_STATUS}. Acceptable status values are NEW, ASSIGNED, POST or MODIFIED" >> "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"
    exit 1
fi

if [ "${BUG_GROUPS}" != '[]' ]; then
    echo "BUG id ${BUG} is marked private, please remove the groups." >> "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"
    exit 1
fi

if [ "${GERRIT_BRANCH}" = "master" ]; then
    if [ "${BUG_VERSION}" != 'mainline' ]; then
        # This is Treated fine, because any user files a bug on release branch,
        # but developers fix the issue on master first. Why bring one more step.
        # Handle it properly in scripts.
        echo "Change filed against the '${GERRIT_BRANCH} branch, but the BUG id is for '${BUG_VERSION}'"
    else
        echo "BUG was filed against mainline/pre-release, change is for master. All good!!"
    fi
    exit 0
fi

# we keep a 2-digit branch, like release-3.4, truncate the BUG_VERSION to 2-digits too
BUG_VER=$(cut -d. -f1,2  <<< "${BUG_VERSION}")
# remove anything before the last '-' sign in the GERRIT_BRANCH
GERRIT_VER=$(sed 's/.*-//' <<< "${GERRIT_BRANCH}")

if [ "${BUG_VER}" != "${GERRIT_VER}" ]; then
    echo "BUG id ${BUG} was filed against version '${BUG_VER}', but the change is sent for '${GERRIT_BRANCH}'" >> "${OUTPUT_FILE}"
    cat "${OUTPUT_FILE}"
    exit 1
fi

echo "BUG was filed against a version, and the change is filed for the correct branch."
exit 0
