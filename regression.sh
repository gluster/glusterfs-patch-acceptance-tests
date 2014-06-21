#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVE_BASE="/archives"
ARCHIVED_BUILDS="archived_builds"
ARCHIVED_LOGS="logs"
TIMESTAMP=`date +%Y%m%d:%T`
SERVER=`hostname`

# Retrieve the Python version
PY_VER=`python -c "import sys; print sys.version[:3]"`

# Point to the build we're testing
export PATH="${BASE}/sbin:${PATH}"
export PYTHONPATH="${BASE}/lib/python${PY_VER}/site-packages:${PYTHONPATH}"
export LIBRARY_PATH="${BASE}/lib:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="${BASE}/lib:${LD_LIBRARY_PATH}"

# Count the number of core files in /
core_count=$(ls -l /core.*|wc -l);

# Run the regression tests
if [ -x ./run-tests.sh ]; then
    # If we're in the root of a GlusterFS source repo, use its tests
    ./run-tests.sh
    RET=$?
elif [ -x ${BASE}/share/glusterfs/run-tests.sh ]; then
    # Otherwise, use the tests in the installed location
    ${BASE}/share/glusterfs/run-tests.sh
    RET=$?
fi

# If there are new core files in /, archive this build for later analysis
cur_count=$(ls -l /core.* 2>/dev/null|wc -l);
if [ ${cur_count} != ${core_count} ]; then
    # Archive the build and any cores
    mkdir -p ${BASE}/cores
    mv /core* ${BASE}/cores
    filename=${ARCHIVED_BUILDS}/build-install-${TIMESTAMP}.tgz
    tar -czf ${ARCHIVE_BASE}/${filename} ${BASE}/{sbin,bin,lib,libexec,cores}

    echo Cores and build archived in http://${SERVER}/${filename}
    # Forcefully fail the regression run if it has not already failed.
    RET=1
fi

# If the regression run fails, then archive the GlusterFS logs for later analysis
if [ ${RET} -ne 0 ]; then
    filename=${ARCHIVED_LOGS}/glusterfs-logs-${TIMESTAMP}.tgz
    tar -czf ${ARCHIVE_BASE}/$filename /var/log;
    echo Logs archived in http://${SERVER}/${filename}
fi

exit ${RET};
