#!/bin/bash

# Set the locations we'll be using
BASE="/build/install"
ARCHIVE_BASE="/archives"
ARCHIVED_BUILDS="archived_builds"
UNIQUE_ID="${JOB_NAME}-${BUILD_ID}"
SERVER=$(hostname)
LIBLIST=${BASE}/cores/liblist.txt

# Create the folders if they don't exist
mkdir -p ${BASE}
mkdir -p ${ARCHIVE_BASE}/${ARCHIVED_BUILDS}

# Clean up old archives
find ${ARCHIVE_BASE} -name '*.tgz' -mtime +15 -delete -type f

# Get the list of shared libraries that the core file uses
# first argument is path to the core file
getliblistfromcore() {
    # Cleanup the tmp file for gdb output
    rm -f ${BASE}/cores/gdbout.txt

    # execute the gdb command to get the share library raw output to file
    gdb -c "$1" -q -ex "set pagination off" -ex "info sharedlibrary" -ex q 2>/dev/null > ${BASE}/cores/gdbout.txt

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

function cleanup_d() {
    local dev

    dev="$(mount | grep "on /d type" | awk '{ print $1; }')"
    if [[ -n "${dev}" ]]; then
        umount /d
        if [[ -f "${dev}" ]]; then
            rm -f "${dev}"
        elif [[ "${dev}" == "/dev/zram"* ]]; then
            zramctl -r "${dev}"
        fi
    fi
}

# Determine the python version used by the installed Gluster
PY_NAME=($(ls "${BASE}/lib/" | grep "python"))
if [[ ${#PY_NAME[@]} -ne 1 ]]; then
    echo "Unable to determine python location" >&2
    exit 1
fi

# Point to the build we're testing
export PATH="${BASE}/sbin${PATH:+:${PATH}}"
export PYTHONPATH="${BASE}/lib/${PY_NAME[0]}/site-packages${PYTHONPATH:+:${PYTHONPATH}}"
export LIBRARY_PATH="${BASE}/lib${LIBRARY_PATH:+:${LIBRARY_PATH}}"
export LD_LIBRARY_PATH="${BASE}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

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

# Cleanup any existing mount on /d and its backend
cleanup_d

# Try to get a zram device to use it as /d. If it's not possible, just use
# a regular file.
D_DEV="$(zramctl -f -s 10G 2>/dev/null)"
D_OPTS=""
if [[ -z "${D_DEV}" ]]; then
    truncate -s 10G /var/data
    D_DEV="/var/data"
    D_OPTS="-o loop"
fi

mkfs.xfs -K -i size=1024 "${D_DEV}"
mount ${D_OPTS} "${D_DEV}" /d

# Count the number of core files in /
core_count=$(ls -l /*.core|wc -l);
old_cores=$(ls /*.core);

# Run the regression tests
if [ -x ./run-tests.sh ]; then
    # If we're in the root of a GlusterFS source repo, use its tests
    ./run-tests.sh "$@"
    RET=$?
elif [ -x ${BASE}/share/glusterfs/run-tests.sh ]; then
    # Otherwise, use the tests in the installed location
    ${BASE}/share/glusterfs/run-tests.sh "$@"
    RET=$?
fi

cleanup_d

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
            set -x
            gdb -ex "core-file ${corefile}" -ex \
                'set pagination off' -ex 'info proc exe' -ex q \
                2>/dev/null
            executable_name=$(gdb -ex "core-file ${corefile}" -ex \
                'set pagination off' -ex 'info proc exe' -ex q \
                2>/dev/null | tail -1 | cut -d "'" -f2 | cut -d " " -f1)
            executable_path=$(which "${executable_name}")
            set +x

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
    # Delete all files that are larger than 1G including the currently archived
    # build if it's too large
    find ${ARCHIVE_BASE} -size +1G -delete -type f

    if [[ ${SERVER} == *"aws"* ]]; then
        scp -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -i "$LOG_KEY" /archives/archived_builds/build-install-${UNIQUE_ID}.tar.bz2 "_logs-collector@logs.aws.gluster.org:/var/www/glusterfs-logs/$JOB_NAME-$BUILD_ID.bz2" || true
        echo "Cores and builds archived in https://logs.aws.gluster.org/$JOB_NAME-$BUILD_ID.bz2"
    else
        echo "Cores and build archived in http://${SERVER}/${filename}.bz2"
    fi
    echo "Open core using the following command to get a proper stack"
    echo "Example: From root of extracted tarball"
    echo "\t\tgdb -ex 'set sysroot ./' -ex 'core-file ./build/install/cores/xxx.core' <target, say ./build/install/sbin/glusterd>"
    # Forcefully fail the regression run if it has not already failed.
    RET=1
fi

if [ ${RET} -ne 0 ]; then
    tar -czf $WORKSPACE/glusterfs-logs.tgz /var/log/glusterfs /var/log/messages*;
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
