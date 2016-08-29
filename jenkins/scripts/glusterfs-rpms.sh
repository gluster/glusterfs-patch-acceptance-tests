#!/bin/bash
./autogen.sh || exit 1
./configure --enable-fusermount || exit 1
cd extras/LinuxRPM
make prep srcrpm || exit 1
sudo mock -r {build_flag} --resultdir=${{WORKSPACE}}/RPMS/"%(dist)s"/"%(target_arch)s"/ --rebuild glusterfs*src.rpm || exit 1
