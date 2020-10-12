#!/bin/bash

set -e;

M=/mnt;
P=/build;
H=$(hostname);
T=600;
V=patchy;


function cleanup()
{
    killall -15 glusterfs glusterfsd glusterd 2>&1 || true;
    killall -9  glusterfs glusterfsd glusterd 2>&1 || true;
    pkill /opt/qa/regression.sh 2>&1
    umount -l $M 2>&1 || true;
    rm -rf /var/lib/glusterd/* /var/log/glusterfs/.cmd_log_history /etc/glusterd/* /var/log/glusterfs/* $P/export;

    rm -f /var/run/glusterd.socket
    rm -rf /var/run/gluster/
    rm -rf $WORKSPACE
}


function main ()
{
    cleanup;
}

main "$@";
