#!/usr/bin/python
#
# Simple script to reboot a VM in the Rackspace Cloud.
#
# Author: Niels de Vos <ndevos@redhat.com>
#

import requests
import json
import sys

# JSON configuration in /etc/rax-reboot.conf
#
# The contents of the file should look like this:
#
# {
#   "username": "someuser",
#   "apikey": "the-key-uuid-thingy",
#   "url": "https://identity.api.rackspacecloud.com/v2.0/tokens"
# }
#
# Note that the JSON format does not allow comments :-/
#

# TODO: make the location configurable
conffile = '/etc/rax-reboot.conf'

# username for https://mycloud.rackspace.com/
username = 'nobody'
# API key from: https://mycloud.rackspace.com/ -> Account Settings
apikey = '00000000000000000000000000000000'
# API endpoint
url = 'https://identity.api.rackspacecloud.com/v2.0/tokens'
# verify https/SSL
verifyssl = True

# TODO: make proxies (or disabling) configurable
proxy=[]

# server to reboot
servername = 'none.example.rax'

# very basic argument parsing
# TODO: use argparse instead
if len(sys.argv) != 2:
    print 'No hostname given, use: %s <HOST>' % sys.argv[0]
    sys.exit(1)

if sys.argv[1] in ['-h', '--help']:
    print "Usage: %s <HOST>" % sys.argv[0]
    sys.exit(0)

servername = sys.argv[1]

# read the configuration parameters from the config file
# TODO: confirm permissions like mode=0600 or mode=0400
cf = open(conffile)
conf = json.load(cf)
cf.close()

try:
    username = conf['username']
except:
    print 'no username set in %s...' % conffile
    sys.exit(1)

try:
    apikey = conf['apikey']
except:
    print 'no apikey set in %s...' % conffile
    sys.exit(1)

try:
    url = conf['url']
except:
    # not fatal, the standard url should be fine
    pass

try:
    verifyssl = conf['verifyssl']
except:
    # not fatal, verifying by default
    pass


# default header, we'll use JSON instead of XML
headers = { 'Content-type': 'application/json' }

# login procedure
login = { 'auth':
		{ 'RAX-KSKEY:apiKeyCredentials':
			{ 'username': username,
			  'apiKey': apikey
			}
		}
	}

response = requests.post(url, data=json.dumps(login), headers=headers, verify=verifyssl, proxies=proxy)

# extend the header with the token
try:
    token = response.json()['access']['token']['id']
except:
    print 'Failed to obtain a token, HTTP returned status %d' % response.status_code
    print 'Contents of the response:\n%s' % response.text
    sys.exit(2)
finally:
    headers['X-Auth-Token'] = token

# find the 'compute' service
services = response.json()['access']['serviceCatalog']
for compute in services + [None]:
    if not compute:
        print 'No compute service found...'
        sys.exit(1)

    if compute['type'] == 'compute':
        break

# loop through all endpoints to get all servers
servers = list()
for ep in compute['endpoints']:
    url = ep['publicURL']

    try:
        response = requests.get(url + '/servers', headers=headers, verify=verifyssl, proxies=proxy)
    except e:
        print e
        continue

    # sometimes decoding the response fails?
    try:
        servers += response.json()['servers']
    except:
        print 'WARNING: Failed to get servers from %s' % url
        continue


# find the server that needs to be rebooted
for server in servers + [None]:
    if not server:
        print 'Server %s not found...' % servername
        sys.exit(1)

    if server['name'] == servername:
        break


# servers have multiple URLs, find one that is called 'self'
for url in server['links'] + [None]:
    if not url:
        print 'Url for %s not found...' % servername
        sys.exit(1)

    if url['rel'] == 'self':
        break

# rebooting is an action, build the full url
url = url['href'] + '/action'

# the reboot command
reboot = {
    'reboot': {
        'type': 'HARD'
    }
}

response = requests.post(url, data=json.dumps(reboot), headers=headers, verify=verifyssl, proxies=proxy)

if response.status_code < 200 or response.status_code > 299:
    print "Something went wrong, sorry! (HTTP status code: %d)" % response.status_code
    sys.exit(2)

