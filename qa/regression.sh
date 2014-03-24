#!/bin/bash

export PATH=/build/install/sbin:$PATH
#export LD_LIBRARY_PATH=/d/build/install/lib
#export LDFLAGS=/d/build/install/lib
#ldconfig

# 2014-03-21 JC Ensure we can find any Gluster Python libs we're testing
export PYTHONPATH=$PYTHONPATH:/build/install/lib/python2.6/site-packages

core_count=$(ls -l /core.*|wc -l);

if [ -x ./run-tests.sh ]; then
    ./run-tests.sh
    RET=$?
elif [ -x /build/install/share/glusterfs/run-tests.sh ]; then
    /build/install/share/glusterfs/run-tests.sh
    RET=$?
fi

cur_count=$(ls -l /core.*|wc -l);
if [ $cur_count != $core_count ]; then
	tar -czf /d/archived_builds/build-install-`date +%Y%m%d:%T`.tgz /build/install/{sbin,bin,lib,libexec};
fi

exit $RET;
