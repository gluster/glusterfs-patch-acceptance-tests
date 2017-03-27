#!/bin/bash

cd glusto-tests/tests
glusto -c ../../gluster_tests_config.yml --pytest='-v -x --junitxml=/tmp/junit.xml'
