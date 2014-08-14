#!/bin/bash -x
#
# Based on the 'rh-bugid' Jenkins job.
#
# Author: Niels de Vos <ndevos@redhat.com>
#

# Not all versions set GERRIT_TOPIC, set it to 'rfc' if no BUG was given
[ -z "${BUG}" -a -z "${GERRIT_TOPIC}" ] && GERRIT_TOPIC='rfc'

BUG=$(git show --name-only --format=email | grep -i '^BUG: ' | cut -f2 -d ' ' | tail -1)
if [ -z "${BUG}" -a "${GERRIT_TOPIC}" = "rfc" ]; then
    echo "No BUG id for rfc needed."
    exit 0
elif [ -z "${BUG}" ]; then
    echo "No BUG id, but topic '${GERRIT_TOPIC}' does not match 'rfc'."
    exit 1
fi

BUG_PRODUCT=""
BZQTRY=0
while [ -z "${BUG_PRODUCT}" ]; do
    BZQTRY=$((${BZQTRY} + 1))
    if [ "x${BZQTRY}" = "x3" ]; then
        echo "Failed to get details for BUG id ${BUG}, please contact an admin or email gluster-infra@gluster.org."
        echo 1
    fi

    # generate an 'export' statement and execute it
    # exports BUG_PRODUCT and BUG_VERSION
    $(bugzilla --verbose query -b ${BUG} --outputformat='export BUG_PRODUCT=%{product} BUG_VERSION=%{version}')
done

if [ "${BUG_PRODUCT}" != "GlusterFS" ]; then
    echo "BUG id ${BUG} belongs to '${BUG_PRODUCT}' and not GlusterFS"
    exit 1
fi

if [ "${GERRIT_BRANCH}" = "master" ]; then
    if [ "${BUG_VERSION}" != 'mainline' -a \
         "${BUG_VERSION}" != 'pre-release' ]; then
            echo "Change filed against the '${GERRIT_BRANCH} branch, but the BUG id is for '${BUG_VERSION}'"
            exit 1
    fi

    # BUG was filed against mainline/pre-release, change is for master
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

# BUG was filed against a version, and the change is filed for the correct branch
exit 0

