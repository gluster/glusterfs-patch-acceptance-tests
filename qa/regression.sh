#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVED_BUILDS="/d/archived_builds"

# Retrieve the Python version
PY_VER=`python --version 2>&1|cut -d ' ' -f 2|cut -d "." -f 1-2`

# Point to the build we're testing
export PATH="${BASE}/sbin:${PATH}"
export PYTHONPATH="${BASE}/lib/python${PY_VER}/site-packages:${PYTHONPATH}"

# Count the number of core files in /
core_count=$(ls -l /core.*|wc -l);

# Run the regression tests
if [ -x ./run-tests.sh ]; then
    # If we're in the root of a Gluster source repo, use its tests
    ./run-tests.sh
    RET=$?
elif [ -x ${BASE}/share/glusterfs/run-tests.sh ]; then
    # Otherwise, use the tests in the installed location
    ${BASE}/share/glusterfs/run-tests.sh
    RET=$?
fi

# If there are new core files in /, archive this build for later analysis
cur_count=$(ls -l /core.*|wc -l);
if [ $cur_count != $core_count ]; then
    tar -czf ${ARCHIVED_BUILDS}/build-install-`date +%Y%m%d:%T`.tgz \
        ${BASE}/{sbin,bin,lib,libexec};
fi

exit ${RET};
