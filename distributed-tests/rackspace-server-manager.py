#!/usr/bin/env python
'''
A script to create and delete the number of servers on Rackspace
'''

import pyrax
import time
import re
import os
import argparse
import uuid


def create_node(nova, counts):
    flavor = nova.flavors.find(name='2 GB General Purpose v1')
    image = nova.images.find(name='centos7-test')
    pubkey = open('key.pub', 'r').read()
    job_name = os.environ.get('JOB_NAME')
    build_number = os.environ.get('BUILD_NUMBER')
    key_name = job_name+'.'+build_number
    nova.keypairs.create(key_name, pubkey)
    for count in range(int(counts)):
        name = 'distributed-testing.'+str(uuid.uuid4())
        node = nova.servers.create(name=name, flavor=flavor.id,
                                   image=image.id, key_name=key_name)

        while node.status == 'BUILD':
            time.sleep(5)
            node = nova.servers.get(node.id)

        ip_address = None
        for network in node.networks['public']:
            if re.match('\d+\.\d+\.\d+\.\d+', network):
                ip_address = network
                f = open('hosts', 'a')
                f.write("{} ansible_host={}\n".format(name, ip_address))
                f.close()
                break
        if ip_address is None:
            print 'No IP address assigned!'
            sys.exit(1)
        print 'The server {0} is waiting at IP address {1}.'.format(count, ip_address)


def delete_node(nova):
    servers = [line.split(' ')[0] for line in open('hosts')]
    for node_name in servers:
        # find the server by name
        server = nova.servers.find(name=node_name)
        server.delete()
        print 'Deleting {0}, please wait...'.format(machine_name)

        # delete the public key on Rackspace
        key_name = os.environ.get('JOB_NAME')+'.'+os.environ.get('BUILD_NUMBER')
        nova.keypairs.delete(key_name)


def main():
    parser = argparse.ArgumentParser(description="Rackspace server creation/deletion")
    parser.add_argument("action", choices=['create', 'delete'], help='Action to be perfromed')
    parser.add_argument("-n", "--count", help='Number of machines')
    parser.add_argument("--region", help='Region to launch the machines', default='ORD')
    args = parser.parse_args()
    count = args.count
    region = args.region

    # configuration of cloud service provider
    pyrax.set_setting('identity_type', 'rackspace')
    pyrax.set_default_region(region)
    pyrax.set_credentials(os.environ.get('USERNAME'),os.environ.get('PASSWORD'))
    nova_obj = pyrax.cloudservers

    if (args.action == 'create'):
        create_node(nova_obj, count)
    elif (args.action == 'delete'):
        delete_node(nova_obj)

main()
