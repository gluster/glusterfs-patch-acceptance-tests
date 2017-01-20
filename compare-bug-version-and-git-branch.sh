#!/bin/bash
#
# Based on the 'rh-bugid' Jenkins job.
#
# Author: Niels de Vos <ndevos@redhat.com>
#

DEBUG=${DEBUG:=0}
[ "${DEBUG}" == '0' ] || set -x

# Not all versions set GERRIT_TOPIC, set it to 'rfc' if no BUG was given
[ -z "${BUG}" -a -z "${GERRIT_TOPIC}" ] && GERRIT_TOPIC='rfc'

# If the second line is not empty, raise an error
# It may be so that the title itself is long, but then it has to be on a single line
# and should not be broken into mutliple lines with new-lines in between
if ! git show --pretty=format:%B | head -n 2 | tail -n 1 | egrep '^$' >/dev/null 2>&1 ; then
    echo "Bad commit message format! Please add an empty line after the subject line. Do not break subject line with new-lines."
    exit 1
fi

BUG=$(git show --name-only --format=email | awk '{IGNORECASE=1} /^BUG:/{print $2}' | tail -1)
if [ -z "${BUG}" -a "${GERRIT_TOPIC}" = "rfc" ]; then
    echo "No BUG id for rfc needed."
    exit 0
elif [ -z "${BUG}" ]; then
    echo "No BUG id, but topic '${GERRIT_TOPIC}' does not match 'rfc'."
    exit 1
elif ! grep -q -e '^master$' -e '^release-' <<< "${GERRIT_BRANCH}" ; then
    echo "Branch '${GERRIT_BRANCH}' can not be mapped to a version, assuming testing only."
    exit 0
fi

# Query bugzilla with 3 retries
[ "${DEBUG}" == '0' ] || BZQOPTS='--verbose'
BUG_PRODUCT=""
BZQTRY=0
while [ -z "${BUG_PRODUCT}" -a ${BZQTRY} -le 3 ]; do
    BZQTRY=$((${BZQTRY} + 1))
    if [ "x${BZQTRY}" = "x3" ]; then
        echo "Failed to get details for BUG id ${BUG}, please verify the bug is not private"
        echo "If the bug is public and readable, please email gluster-infra@gluster.org."
        echo 1
    fi

    BZQOUT=$(bugzilla ${BZQOPTS} query -b ${BUG} --outputformat='%{product}:%{version}:%{groups}:%{status}')
    BUG_PRODUCT=$(cut -d: -f1 <<< "${BZQOUT}")
    BUG_VERSION=$(cut -d: -f2 <<< "${BZQOUT}")
    BUG_GROUPS=$(cut -d: -f3 <<< "${BZQOUT}")
    BUG_STATUS=$(cut -d: -f4 <<< "${BZQOUT}")
done

if [ "${BUG_STATUS}" != "NEW" -a "${BUG_STATUS}" != "POST" -a "${BUG_STATUS}" != "ASSIGNED" ]; then
    echo "BUG id ${BUG} has an invalid status as ${BUG_STATUS}. Acceptable status values are NEW, ASSIGNED or POST."
    exit 1
fi

if [ "${BUG_GROUPS}" != '[]' ]; then
    echo "BUG id ${BUG} is marked private, please remove the groups."
    exit 1
fi

if [ "${BUG_PRODUCT}" != "GlusterFS" ]; then
    echo "BUG id ${BUG} belongs to '${BUG_PRODUCT}' and not 'GlusterFS'."
    exit 1
fi

if [ "${GERRIT_BRANCH}" = "master" ]; then
    if [ "${BUG_VERSION}" != 'mainline' -a \
         "${BUG_VERSION}" != 'pre-release' ]; then
            echo "Change filed against the '${GERRIT_BRANCH} branch, but the BUG id is for '${BUG_VERSION}'"
            exit 1
    fi

    echo "BUG was filed against mainline/pre-release, change is for master."
    exit 0
fi

# we keep a 2-digit branch, like release-3.4, truncate the BUG_VERSION to 2-digits too
BUG_VER=$(cut -d. -f1,2  <<< "${BUG_VERSION}")
# remove anything before the last '-' sign in the GERRIT_BRANCH
GERRIT_VER=$(sed 's/.*-//' <<< "${GERRIT_BRANCH}")

if [ "${BUG_VER}" != "${GERRIT_VER}" ]; then
    echo "BUG id ${BUG} was filed against version '${BUG_VER}', but the change is sent for '${GERRIT_BRANCH}'"
    exit 1
fi

echo "BUG was filed against a version, and the change is filed for the correct branch."
exit 0
