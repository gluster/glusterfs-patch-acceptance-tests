#!/bin/bash

set -e
set -x
printenv > env
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no env root@$(cat $WORKSPACE/hosts):env
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/$1 root@$(cat $WORKSPACE/hosts):$1
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) ./$1
