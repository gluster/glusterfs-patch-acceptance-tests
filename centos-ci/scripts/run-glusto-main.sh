#!/bin/bash
# Run ansible script to setup everything
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml
# Retry ansible scripts in case something fails.
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts --limit @centos-ci/scripts/setup-glusto.retry centos-ci/scripts/setup-glusto.yml
# Retry ansible scripts in case something fails.
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts --limit @centos-ci/scripts/setup-glusto.retry centos-ci/scripts/setup-glusto.yml

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# run the test command from master
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/run-glusto.sh root@${host}:run-glusto.sh
JENKINS_STATUS=$(ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host ./run-glusto.sh)
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host:/tmp/glustomain.log .
exit $JENKINS_STATUS
