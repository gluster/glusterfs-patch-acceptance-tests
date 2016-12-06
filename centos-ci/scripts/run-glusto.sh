#!/bin/bash

set -e
cd glusto-tests/tests
glusto -c ../../gluster_tests_config.yml --pytest='-v -x bvt'"
