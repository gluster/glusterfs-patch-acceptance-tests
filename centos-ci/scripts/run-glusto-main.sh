#!/bin/bash
# Run ansible script to setup everything

# Retry Ansible runs thrice
MAX=3

RETRY=0
RETURN_VALUE=1
while [ $RETRY -lt $MAX ] && [ $RETURN_VALUE -eq 0 ];
do
    RETURN_VALUE=ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml
done

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# run the test command from master
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/run-glusto.sh root@${host}:run-glusto.sh
JENKINS_STATUS=$(ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host ./run-glusto.sh)
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log .
exit $JENKINS_STATUS
