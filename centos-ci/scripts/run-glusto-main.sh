#!/bin/bash
# Run ansible script to setup everything

# Retry Ansible runs thrice
MAX=3

RETRY=0
while [ $RETRY -lt $MAX ];
do
    BRANCH=$BRANCH ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml
    RETURN_CODE=$?
    if [ $RETURN_CODE -eq 0 ]; then
        break
    fi
    RETRY=$((RETRY+1))
done

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# run the test command from master
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/run-glusto.sh root@${host}:run-glusto.sh
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host ./run-glusto.sh
JENKINS_STATUS=$?
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log .
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/junit.xml .
exit $JENKINS_STATUS
