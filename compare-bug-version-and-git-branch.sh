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

if [ -z "${REF}" ]; then
    cat <<EOF >> "${OUTPUT_FILE}"
=== Missing a github issue reference in commit! ===

Gluster commits are made with a reference to a github issue

A check on the commit message, reveals that there is no github
issue referenced in the commit message. Please pick an issue
from the list below [1]:

[1] https://github.com/gluster/glusterfs/issues

Please file an github issue and reference the same in the
commit message using the following tags:
"Fixes: gluster/glusterfs#nnnn" OR "Updates: gluster/glusterfs#nnnn" OR
"Fixes: #nnnn" OR "Updates: #nnnn",
where 'nnnn' is the issue number

Please resubmit your patch with reference to get +1 vote from this job
EOF
    cat "${OUTPUT_FILE}"
    exit 1
fi

exit 0
