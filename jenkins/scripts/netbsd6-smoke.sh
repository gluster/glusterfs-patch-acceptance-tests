#!/bin/bash

/opt/qa/build.sh
RET=$?
echo $RET
if [ $RET -ne 0 ]; then
    exit 1
fi

exit $RET
