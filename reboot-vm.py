#!/usr/bin/env python

import argparse
import os
import sys
from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver


def main(name=None):
    # Try to get rackspace keys
    RACKSPACE_USER = os.environ.get('RS_USER')
    RACKSPACE_KEY = os.environ.get('RS_KEY')
    if RACKSPACE_USER is None or RACKSPACE_KEY is None:
        raise Exception('RS_USER or RS_KEY not defined')

    RackspaceDriver = get_driver(Provider.RACKSPACE)
    driver = RackspaceDriver(RACKSPACE_USER, RACKSPACE_KEY, region='ord')
    nodes = driver.list_nodes()

    for node in nodes:
        if node.name == name:
            node.reboot()
            return
    sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Reboot cloud VMs")
    parser.add_argument('-n', '--node', required=True, help='Name of the node')
    args = parser.parse_args()
    main(args.node)
