#!/bin/bash

virtualenv vdistaf
source vdistaf/bin/activate
pip install rpyc unittest-xml-reporting pyaml python-cicoclient
# Both $NUMBER_OF_SERVERS and $NUMBER_OF_CLIENTS come from
# parametarized build in jenkins job
cico --api-key $( cat ~/duffy.key ) node get --arch x86_64 --release 7 \
    --count $NUMBER_OF_SERVERS -f yaml | grep -v SSID >servers.yml
cico --api-key $( cat ~/duffy.key ) node get --arch x86_64 --release 7 \
    --count $NUMBER_OF_CLIENTS -f yaml | grep -v SSID >clients.yml

git clone https://github.com/gluster/distaf.git
python glusterfs-patch-acceptance-tests/centos-ci/update_distaf_config.py
pushd .
python main.py -c ../distaf_config.yml -f \
    tests_d/example/test_basic_gluster_tests.py
popd
cico --api-key $( cat ~/duffy.key ) node done $( grep comment servers.yml | \
    awk '{print $NF}' | tail -n 1 )
cico --api-key $( cat ~/duffy.key ) node done $( grep comment clients.yml | \
    awk '{print $NF}' | tail -n 1 )
rm -f servers.yml clients.yml
deactivate
