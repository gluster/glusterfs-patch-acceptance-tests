#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVE_BASE="/archives"
ARCHIVED_BUILDS="archived_builds"
ARCHIVED_LOGS="logs"
UNIQUE_ID="${JOB_NAME}-${BUILD_ID}"
SERVER=`hostname`
LIBLIST=${BASE}/cores/liblist.txt

# Create the folders if they don't exist
mkdir -p ${BASE}
mkdir -p ${ARCHIVE_BASE}/${ARCHIVED_BUILDS}
mkdir -p ${ARCHIVE_BASE}/${ARCHIVED_BUILDS}

# Clean up old archives
find ${ARCHIVE_BASE} -name '*.tgz' -mtime +15 -delete

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

# save core_patterns
case $(uname -s) in
    'Linux')
        old_core_pattern=$(/sbin/sysctl -n kernel.core_pattern)
        /sbin/sysctl -w kernel.core_pattern="/%e-%p.core"
        ;;
    'NetBSD')
        old_core_pattern=$(/sbin/sysctl -n kern.defcorename)
        /sbin/sysctl -w kern.defcorename="/%n-%p.core"
        ;;
esac

# Count the number of core files in /
core_count=$(ls -l /*.core|wc -l);
old_cores=$(ls /*.core);

# Run the regression tests
if [ -x ./run-tests.sh ]; then
    # If we're in the root of a GlusterFS source repo, use its tests
    ./run-tests.sh $@
    RET=$?
elif [ -x ${BASE}/share/glusterfs/run-tests.sh ]; then
    # Otherwise, use the tests in the installed location
    ${BASE}/share/glusterfs/run-tests.sh $@
    RET=$?
fi

# If there are new core files in /, archive this build for later analysis
cur_count=$(ls -l /*.core 2>/dev/null|wc -l);
cur_cores=$(ls /*.core 2>/dev/null);

if [ ${cur_count} != ${core_count} ]; then

    declare -a corefiles
    for word1 in ${cur_cores}; do
        for word2 in ${old_cores}; do
            if [ ${word1} == ${word2} ]; then
                x=1
                break;
            fi
        done
        if [[ ${x} -eq 0 ]]; then
            corefiles=("${corefiles[@]}" "${word1}")
        fi
        x=0
    done

    core_count=$(echo "${corefiles[@]}" | wc -w)
    # Dump backtrace of generated corefiles
    if [ ${core_count} -gt 0 ]; then
        for corefile in "${corefiles[@]}"
        do
            executable_name=$(echo ${corefile} | awk -F'-' '{ print $1 }' \
                              | cut -d'/' -f2)
            executable_path=$(which ${executable_name})

            echo ""
            echo "========================================================="
            echo "              Start printing backtrace"
            echo "         program name : ${executable_path}"
            echo "         corefile     : ${corefile}"
            echo "========================================================="
            gdb -nx --batch --quiet -ex "thread apply all bt full"         \
                -ex "quit" --exec=${executable_path} --core=${corefile}
            echo "========================================================="
            echo "              Finish backtrace"
            echo "         program name : ${executable_path}"
            echo "         corefile     : ${corefile}"
            echo "========================================================="
            echo ""
        done
    fi
    # Archive the build and any cores
    mkdir -p ${BASE}/cores
    mv /*.core ${BASE}/cores
    filename=${ARCHIVED_BUILDS}/build-install-${UNIQUE_ID}.tar

    # Remove temporary files generated to stash libraries from cores
    rm -f ${LIBLIST}
    rm -f ${LIBLIST}.tmp

    #Generate library list from all cores
    CORELIST="$(ls ${BASE}/cores/*.core)"
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
    echo         "gdb -ex 'set sysroot ./' -ex 'core-file ./build/install/cores/xxx.core' <target, say ./build/install/sbin/glusterd>"
    # Forcefully fail the regression run if it has not already failed.
    RET=1
fi

# If the regression run fails, then archive the GlusterFS logs for later analysis
if [ ${RET} -ne 0 ]; then
    filename=${ARCHIVED_LOGS}/glusterfs-logs-${UNIQUE_ID}.tgz
    tar -czf ${ARCHIVE_BASE}/$filename /var/log/glusterfs /var/log/messages*;
    echo Logs archived in http://${SERVER}/${filename}
fi

# reset core_patterns
case $(uname -s) in
    'Linux')
        /sbin/sysctl -w kernel.core_pattern="${old_core_pattern}"
        ;;
    'NetBSD')
        /sbin/sysctl -w kern.defcorename="${old_core_pattern}"
        ;;
esac

exit ${RET};
