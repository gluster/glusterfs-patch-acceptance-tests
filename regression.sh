#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVE_BASE="/archives"
ARCHIVED_BUILDS="archived_builds"
ARCHIVED_LOGS="logs"
TIMESTAMP=`date +%Y%m%d:%T`
SERVER=`hostname`
LIBLIST=${BASE}/cores/liblist.txt

# Get the list of shared libraries that the core file uses
# first argument is path to the core file
getliblistfromcore() {
    # Cleanup the tmp file for gdb output
    rm -f ${BASE}/cores/gdbout.txt

    # execure the gdb command to get the share library raw output to file
    gdb -c $1 -q -ex "info sharedlibrary" -ex q 2>/dev/null > ${BASE}/cores/gdbout.txt

    # For each line start extracting the sharelibrary paths once we see
    # the text line "Shared Object Path" in the raw gdb output. Append this
    # in the an output file.
    set +x
    local STARTPR=0
    while IFS=' ' read -r f1 f2 f3 f4 f5 f6 f7 fdiscard; do
        if [[ $STARTPR == 1 && "$f4" != "" ]]; then
                printf "%s\n" $f4 >> ${LIBLIST}
        fi
        if [[ "$f5" == "Shared" && "$f6" == "Object" && "$f7" == "Library" ]]; then
                STARTPR=1
        fi
    done < "${BASE}/cores/gdbout.txt"
    set -x

    # Cleanup the tmp file for gdb output
    rm -f ${BASE}/cores/gdbout.txt
}

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
    filename=${ARCHIVED_BUILDS}/build-install-${TIMESTAMP}.tar

    # Remove temporary files generated to stash libraries from cores
    rm -f ${LIBLIST}
    rm -f ${LIBLIST}.tmp

    #Generate library list from all cores
    CORELIST="$(ls ${BASE}/cores/core.*)"
    for corefile in $CORELIST; do
        getliblistfromcore $corefile
    done

    # Get rid of duplicates
    sort ${LIBLIST} | uniq > ${LIBLIST}.tmp 2>/dev/null

    # Get rid of BASE dir libraries as they are already packaged
    cat ${LIBLIST}.tmp | grep -v "${BASE}" > ${LIBLIST}

    # tar the dependent libraries and other stuff for analysis
    tar -cf ${ARCHIVE_BASE}/${filename} ${BASE}/{sbin,bin,lib,libexec,cores}
    # Append to the tar ball the system libraries that were part of the cores
    # 'h' option is so that the links are followed and actual content is in the tar
    tar -rhf ${ARCHIVE_BASE}/${filename} -T ${LIBLIST}
    bzip2 ${ARCHIVE_BASE}/${filename}

    # Cleanup the temporary files
    rm -f ${LIBLIST}
    rm -f ${LIBLIST}.tmp

    echo Cores and build archived in http://${SERVER}/${filename}.bz2
    echo Open core using the following command to get a proper stack...
    echo Example: From root of extracted tarball
    echo         "gdb -ex 'set sysroot ./' -ex 'core-file ./build/install/cores/core.xxx' <target, say ./build/install/sbin/glusterd>"
    # Forcefully fail the regression run if it has not already failed.
    RET=1
fi

# If the regression run fails, then archive the GlusterFS logs for later analysis
if [ ${RET} -ne 0 ]; then
    filename=${ARCHIVED_LOGS}/glusterfs-logs-${TIMESTAMP}.tgz
    tar -czf ${ARCHIVE_BASE}/$filename /var/log/glusterfs;
    echo Logs archived in http://${SERVER}/${filename}
fi

exit ${RET};
