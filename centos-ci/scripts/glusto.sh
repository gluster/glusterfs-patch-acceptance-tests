#!/bin/bash

# run ansible script to setup everything
ANSIBLE_HOST_KEY_CHECKING=False $HOME/env/bin/ansible-playbook -i hosts setup-glusto.yml

# Get master IP
host=$(cat hosts | grep ansible_host | head -n 1 | awk '{split($2, a, "="); print a[2]}')
cmd="cd glusto-tests/tests && glusto -c ../../gluster_tests_config.yml --pytest='-v -x bvt'"

# run the test command from master
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$host $cmd
