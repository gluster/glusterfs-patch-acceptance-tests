#!/bin/bash

set -e
set -x
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $1 root@$(cat $WORKSPACE/hosts):$1
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) ./$1
