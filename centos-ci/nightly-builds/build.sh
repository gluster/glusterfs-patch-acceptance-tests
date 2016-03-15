#!/bin/bash

artifact()
{
	[ -e ~/rsync.passwd ] || return 0
	rsync -av --password-file ~/rsync.passwd ${@} gluster@artifacts.ci.centos.org::gluster/nightly/
}

# if anything fails, we'll abort
set -e

# install basic dependencies for building the tarball and srpm
yum -y install git autoconf automake gcc libtool bison flex make rpm-build mock createrepo_c
# gluster repositories contain additional -devel packages
yum -y install centos-release-gluster
yum -y install python-devel libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel

# clone the repository, github is faster than our Gerrit
#git clone https://review.gluster.org/glusterfs
git clone https://github.com/gluster/glusterfs
cd glusterfs/

# switch to the branch we want to build
git checkout ${GERRIT_BRANCH}

# generate a version based on branch.date.last-commit-hash
if [ ${GERRIT_BRANCH} = 'master' ]; then
	GIT_VERSION=''
	GIT_HASH="$(git log -1 --format=%h)"
	VERSION="$(date +%Y%m%d).${GIT_HASH}"
else
	GIT_VERSION="$(sed 's/.*-//' <<< ${GERRIT_BRANCH})"
	GIT_HASH="$(git log -1 --format=%h)"
	VERSION="${GIT_VERSION}.$(date +%Y%m%d).${GIT_HASH}"
fi

# overload some variables to match the auto-generated version
if [ -x build-aux/pkg-version ]; then
	VERSION="$(build-aux/pkg-version --version)"
fi

# unique tag to use in git
TAG="${VERSION}-$(date +%Y%m%d).${GIT_HASH}"

if grep -q -E '^AC_INIT\(.*\)$' configure.ac; then
	# replace the default version by our autobuild one
	sed -i "s/^AC_INIT(.*)$/AC_INIT([glusterfs],[${VERSION}],[gluster-devel@gluster.org])/" configure.ac

	# Add a note to the ChangeLog (generated with 'make dist')
	git commit -q -n --author='Autobuild <gluster-devel@gluster.org>' \
		-m "autobuild: set version to ${VERSION}" configure.ac
fi

# generate the tar.gz archive
./autogen.sh
./configure
rm -f *.tar.gz
make dist

# build the SRPM
rm -f *.src.rpm
SRPM=$(rpmbuild --define 'dist .autobuild' --define "_srcrpmdir ${PWD}" \
	--define '_source_payload w9.gzdio' \
	--define '_source_filedigest_algorithm 1' \
	-ts glusterfs-${VERSION}.tar.gz | cut -d' ' -f 2)

# do the actual RPM build in mock
# TODO: use a CentOS Storage SIG buildroot
RESULTDIR=/srv/gluster/nightly/${GERRIT_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
/usr/bin/mock \
	--root epel-${CENTOS_VERSION}-${CENTOS_ARCH} \
	--resultdir ${RESULTDIR} \
	--rebuild ${SRPM}

pushd ${RESULTDIR}
createrepo_c .
popd

pushd /srv/gluster/nightly
artifact ${GERRIT_BRANCH}
popd

exit ${RET}

