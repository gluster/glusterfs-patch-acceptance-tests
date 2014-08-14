#!/bin/bash -x

BUG=$(git show --name-only | grep 'BUG: ' | cut -f2 -d: | tail -1)
if [ "x$BUG" = x ]; then
    echo "No BUG id"
    exit 0
fi

PRODUCT=""
BZQTRY=0
while [ "x$PRODUCT" = "x" ]; do
    BZQTRY=$(($BZQTRY + 1))
    if [ "x$BZQTRY" = "x3" ]; then
        break
    fi
    PRODUCT=$(bugzilla --verbose query -b $BUG --outputformat='%{product}')
done

if [ "x$PRODUCT" != "xGlusterFS" ]; then
    echo "BUG id $BUG belongs to '$PRODUCT' and not GlusterFS"
    exit 1;
else
    exit 0;
fi
