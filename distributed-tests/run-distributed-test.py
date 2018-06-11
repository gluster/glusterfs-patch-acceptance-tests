#!/usr/bin/env python
import subprocess
import os
from ansible.parsing.dataloader import DataLoader
from ansible.vars.manager import VariableManager
from ansible.inventory.manager import InventoryManager


def get_ansible_host_ip():
   loader = DataLoader()
   inventory = InventoryManager(loader=loader, sources='hosts')
   variable_manager = VariableManager(loader=loader, inventory=inventory)
   hostnames = []
   for host in inventory.get_hosts():
       hostnames.append(variable_manager.get_vars(host=host))
   ip = ' '.join([str(i['ansible_host']) for i in hostnames])
   return str(ip)


def main():
    max_attempts = 3
    ip = get_ansible_host_ip()
    rv = subprocess.call(['./extras/distributed-testing/distributed-test.sh', '--hosts', '%s' % ip, '--id-rsa', 'key', '-v'])
    while max_attempts != 1 and rv != 0:
        rv = subprocess.call(['./extras/distributed-testing/distributed-test.sh', '--hosts', '%s' % ip, '--id-rsa', 'key', '-v'])
        max_attempts = max_attempts - 1


main()
