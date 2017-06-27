#!/bin/bash

cd glusto-tests/tests
glusto -c ../../gluster_tests_config.yml --pytest='-v -x functional/bvt/test_basic.py --junitxml=/tmp/bvt-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v -x functional/bvt/test_vvt.py --junitxml=/tmp/vvt-junit.xml'
glusto -c ../../gluster_tests_config.yml --pytest='-v -x functional/bvt/test_cvt.py  --junitxml=/tmp/cvt-junit.xml'
