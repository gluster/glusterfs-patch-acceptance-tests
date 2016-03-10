#!/usr/bin/env python

import yaml
import os

def get_ci_centos_nodes(yaml_file_path):
    """
        Get the list of nodes from the yml file returned by cico
    """
    with open(yaml_file_path, "r") as f:
        cinodes = yaml.load(f)
    nodes = []
    if cinodes is not None:
        for node in cinodes:
            nodes.append("%s.ci.centos.org" % node['hostname'])
    return nodes

def remove_the_nodes(yaml_config, dkey):
    """
        Removes the nodes from the yaml config dict
    """
    old_nodes = yaml_config[dkey].keys()
    for node in old_nodes:
        yaml_config[dkey].pop(node, None)
    return yaml_config

def update_the_nodes(yaml_config, dkey, nlist):
    """
        Updates the nodes with the new list
    """
    for node in nlist:
        yaml_config[dkey][node] = {}
    return yaml_config


if __name__ == '__main__':
    # Load the machines provisioned by duffy
    servers = get_ci_centos_nodes('servers.yml')
    #peers = get_ci_centos_nodes('peers.yml')
    peers = []
    clients = get_ci_centos_nodes('clients.yml')

    # Load the distaf configs
    with open("distaf/config.yml", "r") as f:
        distaf_config = yaml.load(f)

    # Remove the nodes, peer and clients from the dict
    for node in ['nodes', 'peers', 'clients']:
        distaf_config = remove_the_nodes(distaf_config, node)

    # Update them with new values
    distaf_config = update_the_nodes(distaf_config, 'nodes', servers)
    distaf_config = update_the_nodes(distaf_config, 'peers', peers)
    distaf_config = update_the_nodes(distaf_config, 'clients', clients)

    # Update the volume part
    for vol in distaf_config['volumes']:
        distaf_config['volumes'][vol]['nodes'] = servers
        distaf_config['volumes'][vol]['peers'] = peers
        distaf_config['volumes'][vol]['clients'] = clients

    # Update the global mode
    distaf_config['global_mode'] = True
    cwd = os.getcwd()
    try:
        os.makedirs('distaf_logs')
    except OsError:
        pass
    distaf_config['log_file'] = "%s/distaf_logs/centos_ci_run.log" % cwd

    # Dump them into config file
    with open("distaf_config.yml", "w") as f:
        yaml.dump(distaf_config, f)
