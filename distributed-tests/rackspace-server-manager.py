#!/usr/bin/python2

'''
A script to create and delete the number of servers on Rackspace
'''

import os
import argparse
import uuid
import socket
import time
from multiprocessing.dummy import Pool
from functools import partial
from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver
from libcloud.compute.deployment import SSHKeyDeployment


def create_node(counts, conn, flavor, image, step):
    '''
    Function to create a node on cloud
    '''
    name = 'distributed-testing-'+str(uuid.uuid4())
    node = conn.deploy_node(
           name=name, image=image, size=flavor, deploy=step
           )
    for ip_addr in node.public_ips:
        try:
            socket.inet_pton(socket.AF_INET, ip_addr)
            ip = ip_addr
        except socket.error:
            continue
    with open('hosts', 'a') as host_file:
        host_file.write("{} ansible_host={}\n".format(name, ip_addr))
    return ip

def delete_node(conn):
    '''
    Function to delete node from cloud
    '''
    servers = [line.split(' ')[0] for line in open('hosts')]
    for node in conn.list_nodes():
        if node.name in servers:
            node.destroy()
            print 'Deleting {0}, please wait...'.format(node.name)


def main():
    parser = argparse.ArgumentParser(description="Rackspace server creation/deletion")
    parser.add_argument("action", choices=['create', 'delete'], help='Action to be performed')
    parser.add_argument("-n", "--count", help='Number of machines')
    parser.add_argument("-w", "--worker", help='Number of worker processes', default=4)
    args = parser.parse_args()

    driver = get_driver(Provider.RACKSPACE)
    conn = driver(
        os.environ.get('USERNAME'),
        os.environ.get('API_KEY'),
        region=os.environ.get('AUTH_SYSTEM_REGION')
        )
    flavor = conn.ex_get_size('performance1-2')
    image = conn.get_image('8bca010c-c027-4947-b9c9-adaae6e4f020')
    with open('key.pub', 'r') as key_file:
        pubkey = key_file.read()

    if not isinstance(pubkey, str):
        pubkey = str(pubkey)

    step = SSHKeyDeployment(pubkey)
    if args.action == 'create':
        pool = Pool(int(args.worker))
        create = partial(create_node, conn=conn, flavor=flavor, image=image, step=step)
        ips = pool.map(create, range(int(args.count)))
        pool.close()
        pool.join()
        print 'The list of servers: {0}'.format(ips)
    elif args.action == 'delete':
        delete_node(conn)

if __name__ == '__main__':
    main()
