#!/bin/bash
set -e
# Run ansible script to setup everything
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml
# Retry ansible scripts in case something fails.
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml -limit @centos-ci/scripts/setup-glusto.retry || true
# Retry ansible scripts in case something fails.
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts centos-ci/scripts/setup-glusto.yml -limit @centos-ci/scripts/setup-glusto.retry || true

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')

# run the test command from master
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos-ci/scripts/run-glusto.sh root@${host}:run-glusto.sh
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host ./run-glusto.sh
