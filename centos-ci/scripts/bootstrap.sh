#!/bin/bash

set -e
set -x
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/$1 root@$(cat $WORKSPACE/hosts):$1
if [ -z $2 ];
then
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) ./$1
else
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) $2 ./$1
fi
