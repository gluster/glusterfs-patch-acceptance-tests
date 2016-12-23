#!/bin/bash

# Retry Ansible runs thrice
MAX=3

RETRY=0
while [ $RETRY -lt $MAX ];
do
    ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-regression.yml
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# Run regressions
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/run-centos-regression.sh root@${host}:run-centos-regression.sh
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host JOB_NAME=$JOB_NAME BUILD_ID=$BUILD_ID ./run-centos-regression.sh
JENKINS_STATUS=$?
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/archives/logs/glusterfs-logs-$JOB_NAME-$BUILD_ID.tgz logs.tgz
exit $JENKINS_STATUS
