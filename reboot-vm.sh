#!/bin/sh
#
# This script needs to run as root, to access the credentials for the rackspace cloud.
#
# Credentials are stored in /etc/rax-reboot.conf
#
sudo $(dirname $0)/rax-reboot/reboot-vm.py ${VM}

