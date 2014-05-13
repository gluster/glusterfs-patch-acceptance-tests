#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVED_BUILDS="/d/archived_builds"
ARCHIVED_LOGS="/d/logs"

# Retrieve the Python version
PY_VER=`python -c "import sys; print sys.version[:3]"`

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
if [ ${cur_count} != ${core_count} ]; then
    mkdir -p ${BASE}/cores;
	  mv /core* ${BASE}/cores;
	  local filename=${ARCHIVED_BUILDS}/build-install-`date +%Y%m%d:%T`.tgz
    tar -czf ${filename} ${BASE}/{sbin,bin,lib,libexec};
    echo Cores and build archived in ${filename}
    ## Forcefully fail the regression run if it has not already failed.
    RET=1
fi

# If the regression run fails, then archive the glusterfs logs for later analysis
if [ ${RET} -ne 0 ]; then
	  local filename=${ARCHIVED_LOGS}/glusterfs-logs-`date +%Y%m%d:%T`.tgz
	  tar -czf $filename ${BASE}/var;
	  echo Logs archived in ${filename}
fi


exit ${RET};
