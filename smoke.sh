#!/bin/sh

set -e;

P=/build
M=$P/mnt;
H=$(hostname);
T=600;
V=patchy;
PATH=$P/install/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/pkg/bin:/usr/local/bin
export PATH
LD_LIBRARY_PATH=$P/install/lib:/lib:/usr/lib:/usr/pkg/lib
export LD_LIBRARY_PATH

cleanup()
{
    pkill -15 glusterfs glusterfsd glusterd 2>&1 || true;
    pkill -9 glusterfs glusterfsd glusterd 2>&1 || true;
    umount -f $M 2>&1 || true;
    rm -rf $P/install/var/db/glusterd/vols/*
    rm -rf $P/var/db/glusterd/vols/
    find $P/install/var/log/glusterfs/ -type f | xargs rm -f
    rm -rf $P/export $M
}

start_fs()
{
    mkdir -p $M
    mkdir -p $P/install/var/log
    mkdir -p $P/export;
    chmod 0755 $P/export;

    glusterd;
    gluster --mode=script volume create $V replica 2 \
	$H:$P/export/export1 $H:$P/export/export2 \
	$H:$P/export/export3 $H:$P/export/export4 force
    gluster volume start $V;
    glusterfs -s $H --volfile-id $V $M;
}


run_tests()
{
    cd $M;

    sleep 5
    prove -r /opt/qa/tools/posix-compliance/tests

    cd -;
}


watchdog ()
{
    # insurance against hangs during the test

    sleep $1;

    echo "Kicking in watchdog after $1 secs";

    cleanup;
}

finish ()
{
    RET=$?
    if [ $RET -ne 0 ]; then
	mkdir -p $P/logs/netbsd7-smoke
        filename=$P/logs/netbsd7-smoke/glusterfs-logs-`date +%Y%m%d%H%M`.tgz
        tar -czf $filename $P/install/var/log
        echo "Logs archived in $H:$filename"
    fi
    cleanup;
}

main ()
{
    cleanup;
    watchdog $T &
    watchdog_pid=$!
    trap finish EXIT;

    set -x;
    start_fs;
    run_tests;
    ret=$?
    set +x;

    kill $watchdog_pid
    return $ret
}

main "$@"
