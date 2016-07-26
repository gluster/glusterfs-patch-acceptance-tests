# Jenkins jobs and scripts for testing Gluster in the CentOS CI

This directory contains the configuration and scripts that get executed in the
[CentOS CI](https://ci.centos.org/view/Gluster/). The tests are maintained by
the Gluster Community, questions or comments about these tests should be sent
to the [main Gluster developers
list](http://www.gluster.org/mailman/listinfo/gluster-devel). Changes to the
test-cases can be sent as GitHub pull requests.

# Current available tests

## nightly-builds
Create RPMs each night and sync them to artifacts.ci.centos.org. There is one
main job is used as a scheduler (`gluster_nightly-rpm-builds`). The actual
building is done by `gluster_build-rpms` and uses several environment
parameters to decide what CentOS version, architecture and Gluster release to
build.

## libgfapi-python
Run the upstream functional tests from the
[libgfapi-python](https://github.com/gluster/libgfapi-python) master branch on
a single brick volume. This test currently installs the latest released version
of GlusterFS from the CentOS Storage SIG.

The job checks every two hours for updates of the [yum 
metadata](http://artifacts.ci.centos.org/gluster/nightly/master/7/x86_64/repodata/repomd.xml)
for CentOS-7/x86_64 and the nightly Gluster RPMs for the master branch. If the
metadata has been updated, a new run is attempted.

## glusterfs-coreutils
Run the upstream functional tests from the
[glusterfs-coreutils](https://github.com/gluster/glusterfs-coreutils) master
branch. This test currently installs the nightly builds from the GlusterFS
Community that are made available on the [CentOS CI Artifacts
server](http://artifacts.ci.centos.org/gluster/nightly/).

The job checks every two hours for updates of the [yum 
metadata](http://artifacts.ci.centos.org/gluster/nightly/master/7/x86_64/repodata/repomd.xml)
for CentOS-7/x86_64 and the nightly Gluster RPMs for the master branch. If the
metadata has been updated, a new run is attempted.

## heketi-functional
Run the upstream functional tests as described in the [Heketi
README](https://github.com/heketi/heketi/blob/master/tests/functional/README.md).
These tests use [Vagrant from the
SCLo](https://wiki.centos.org/SpecialInterestGroup/SCLo/Vagrant) that is
provided in CentOS.

The job checks every two hours for updates of the [yum 
metadata](http://artifacts.ci.centos.org/gluster/nightly/master/7/x86_64/repodata/repomd.xml)
for CentOS-7/x86_64 and the nightly Gluster RPMs for the master branch. If the
metadata has been updated, a new run is attempted. The test run itself [does
not use the nightly build Gluster repository
yet](https://github.com/heketi/heketi/issues/396) though.

## nightly-vagrant
The 3.8 version and the master branch have the `run-tests-in-vagrant.sh`
scripts. These versions can be used in the CentOS CI to run tests.

At midnight, four tests get scheduled:
 - GlusterFS master on CentOS-6
 - GlusterFS master on Fedora
 - GlusterFS release-3.8 on CentOS-6
 - GlusterFS release-3.8 on Fedora

The version of Fedora comes from the Gluster upstream script and can not be
chosen.
