#!/bin/bash

cd glusto-tests/tests
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_basic.py --junitxml=/tmp/bvt-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_vvt.py --junitxml=/tmp/vvt-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/bvt/test_cvt.py  --junitxml=/tmp/cvt-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/afr  --junitxml=/tmp/afr-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/glusterd  --junitxml=/tmp/glusterd-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v functional/nfs_ganesha  --junitxml=/tmp/nfs-ganesha-junit.xml'
