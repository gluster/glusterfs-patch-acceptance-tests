# Jenkins jobs and scripts for testing Gluster in the CentOS CI

This directory contains the configuration and scripts that get executed in the
[CentOS CI](https://ci.centos.org/view/Gluster/). The tests are maintained by
the Gluster Community, questions or comments about these tests should be sent
to the [main Gluster developers
list](http://www.gluster.org/mailman/listinfo/gluster-devel). Changes to the
test-cases can be sent as GitHub pull requests.

# Current available tests

## libgfapi-python
Run the upstream functional tests from the
(libgfapi-python)[https://github.com/gluster/libgfapi-python] master branch on
a single brick volume. This test currently installs the latest released version
of GlusterFS from the CentOS Storage SIG. In future it should use the nightly
builds from an other CentOS CI job that places the RPMs on
http://artifacts.ci.centos.org/gluster/

