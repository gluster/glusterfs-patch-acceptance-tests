#!/bin/bash -ex

prove -q -r /opt/qa/tools/posix-compliance/tests
prove -q -r /opt/qa/tools/posix-compliance-latest/tests
