#!/usr/local/bin/bash

# Added by JD on 2016/03/07 because I don't have access to edit build.sh and I'm tired
# of these tests failing due to permissions errors in glupy.
glupydir=/usr/local/lib/python2.7/site-packages/gluster
sudo mkdir -p $glupydir
sudo chown jenkins $glupydir
sudo chmod 755 $glupydir

/opt/qa/build.sh
RET=$?
echo $RET
if [ $RET -ne 0 ]; then
    exit 1
fi

#sudo /opt/qa/smoke.sh
#RET=$?
#echo smoke.sh returned $RET
exit $RET
