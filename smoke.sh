#!/usr/bin/env bash

set -e;

M=/mnt;
P=/build;
H=http.int.rht.gluster.org
T=600;
V=patchy;
UNIQUE_ID="${JOB_NAME}-${BUILD_ID}"
export PATH=$PATH:$P/install/sbin

function cleanup()
{
    killall -15 glusterfs glusterfsd glusterd 2>&1 || true;
    killall -9 glusterfs glusterfsd glusterd 2>&1 || true;
    umount -l $M 2>&1 || true;
    rm -rf /build/dbench-logs
    rm -rf /var/lib/glusterd /var/log/glusterfs/* /etc/glusterd $P/export;
}

function start_fs()
{
    mkdir -p $P/export;
    chmod 0755 $P/export;

    glusterd;
    gluster --mode=script volume create $V replica 2 $H:$P/export/export{1,2,3,4} force;
    gluster volume start $V;
    gluster volume set $V performance.write-behind off;
    glusterfs -s $H --volfile-id $V $M;
#    mount -t glusterfs $H:/$V $M;
}


function run_tests()
{
    cd $M;

    (sleep 1; dbench -s -t 60 10 > /build/dbench-logs) &

    (sleep 1; /opt/qa/tools/posix_compliance.sh) &

    wait %2
    wait %3

    rm -rf clients;

    cd -;
}


function watchdog ()
{
    # insurance against hangs during the test
    sleep $1;
    echo "Kicking in watchdog after $1 secs";
    # Get core
    set -x
    local client_pid=$(ps aux | grep glusterfs | grep -v glusterfsd | grep patchy | awk '{print $2}')
    if [ ! -z $client_pid ]; then gcore -o /var/log/glusterfs/gluster-gdb.core $client_pid; fi
    # Get statedumps
    local mount_pid=$(ps auxww | grep glusterfs | grep -E "volfile-id[ =]/?$V " | awk '{print $2}' | head -1)
    if [ ! -z $mount_pid ]; then kill -USR1 $mount_pid; fi
    gluster volume statedump $V
    sleep 5; #Give some time for the statedumps to be generated
    # Kill the gluster processes so FINISH is triggered
    killall -15 glusterfs glusterfsd glusterd 2>&1 || true;
    killall -9 glusterfs glusterfsd glusterd 2>&1 || true;
    umount -l $M 2>&1 || true;
    set +x
}

function finish ()
{
    RET=$?
    if [ $RET -ne 0 ]; then
        cat /build/dbench-logs || true
    fi
    #Move statedumps to be archived
    mv /var/run/gluster/*dump* /var/log/glusterfs/ || true
    filename=glusterfs-logs-${UNIQUE_ID}.tgz
    tar -czf ${WORKSPACE}/$filename /var/log/glusterfs /var/log/messages* || true
    # $http_int_priv is the credential binding variable defined in a job
    scp -i $http_int_priv ${WORKSPACE}/$filename _logs-collector@$H:/var/www/glusterfs-logs
    echo Logs archived at http://$H/$filename
    cleanup;
    kill %1;
}

function main ()
{
    cleanup;

    watchdog $T &

    trap finish EXIT;

    set -x;

    start_fs;

    run_tests;
}

main "$@";
