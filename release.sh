#!/bin/bash -eux

#
# Usage steps
#
# 1. Make sure $HOME is set and you have write permissions in $HOME/work/
#
# 2. Clone glusterfs.git (from http://git.gluster.com) as $HOME/work/glusterfs.git
#
# 3. Tag the commit id from which you are about to make a release with the release
#    name prefixed by a "v". If you want to make 2.0.6rc5 release from the HEAD
#    of release-2.0 branch, you need to:
#
#    sh$ git checkout -b release-2.0 origin/release-2.0 # only for the first time on the tree
#    sh$ git tag v2.0.6rc5 # this tags the HEAD of release-2.0 branch as "v2.0.6rc5"
#
# 4. Execute glusterfs-release with the release name, WITHOUT the "v" prefix. For e.g.
#
#    sh$ glusterfs-release 2.0.6rc5
#
# 5. Keep inspecting the script output watching it make the tarball, compile test it,
#    upload it to qa-releases directory and send out the announcement email
#

set -xe

function init_vars()
{
    REVISION="glusterfs.git";

    if [ "x$RELEASE_VERSION" = "x" ]; then
        echo "FATAL: Unspecified \$RELEASE_VERSION"
        exit 1
    fi
    VERSION="$RELEASE_VERSION";

    if [ "x$GERRIT_REFSPEC" = "x" ]; then
        echo "FATAL: Unspecified \$GERRIT_REFSPEC"
        exit 1
    fi
    REFSPEC="$GERRIT_REFSPEC";

    if [ "x$ANNOUNCE_EMAIL" = "x" ]; then
        ANNOUNCE_EMAIL="avati@redhat.com, vbellur@redhat.com";
    fi
    EMAIL="$ANNOUNCE_EMAIL";

    #REPO=git://git.sv.gnu.org/glusterfs.git
    REPO="$(pwd)";
    BASEDIR="$HOME/work/releases";
    INSTALLDIR="$BASEDIR/$VERSION/install";
    TARBALL="glusterfs-$VERSION.tar.gz";
    UFOTARBALL="gluster-swift-ufo-$VERSION.tar.gz";
    SWIFT_VERSION="1.8.0"
    RPMBUILD="$HOME/rpmbuild/RPMS"

    PFX="pub/gluster/glusterfs";
    BITS="/$PFX";

    PATCHSET="";
}

function prepare_dirs()
{
    rm -rf $BASEDIR;
    mkdir -p $BASEDIR;
    mkdir $BASEDIR/$VERSION;
    mkdir $INSTALLDIR;
}

function get_src()
{
    git clone $REPO $BASEDIR/$VERSION/$REVISION;
    cd $BASEDIR/$VERSION/$REVISION;
    git checkout $REFSPEC;
    PATCHSET=$(git describe);
    sed -i "s/^AC_INIT(.*)$/AC_INIT([glusterfs],[${VERSION}],[gluster-users@gluster.org])/" configure.ac
    git log > ChangeLog;
}

function make_tarball()
{
    cd $BASEDIR/$VERSION/$REVISION;
    ./autogen.sh;
    #mkdir build;
    #cd build;
    ./configure --enable-fusermount>/dev/null;
    make dist >/dev/null;
    cp *.tar.gz ..
}

function make_rpm()
{
    if [ "x$BUILD_RPMS" != "xtrue" ]; then
        echo "Skipping RPMBUILD. BUILD_RPMS='$BUILD_RPMS'";
        return;
    fi

    rm -rvf $HOME/rpmbuild;
    if [ -d extras/LinuxRPM ]; then
        make -C extras/LinuxRPM glusterrpms;
        if [ ! -d $RPMBUILD/x86_64 ]; then
            mkdir -p $RPMBUILD/x86_64 $RPMBUILD/noarch $RPMBUILD/SRPMS
        fi
        cp extras/LinuxRPM/*.x86_64.rpm $RPMBUILD/x86_64/
        cp extras/LinuxRPM/*.noarch.rpm $RPMBUILD/noarch/
        cp extras/LinuxRPM/*.src.rpm $RPMBUILD/SRPMS/
    else
        rpmbuild -ta $BASEDIR/$VERSION/glusterfs-$VERSION.tar.gz;
    fi
}

function cp_tarball()
{
    mkdir $BITS/src -p;
    cp $BASEDIR/$VERSION/gluster*-$VERSION.tar.gz $BITS/src/
    sha256sum $BITS/src/gluster*-$VERSION.tar.gz > $BITS/src/gluster*-$VERSION.sha256sum
}

function stage_bits()
{
    rm -rf $BITS/stage;

    rm -rf $BITS/$VERSION;
    mkdir $BITS/$VERSION;
    mkdir $BITS/$VERSION/repodata;

    ln -s $VERSION $BITS/stage;

    cp -r $RPMBUILD/* $BITS/stage;

    cat > $BITS/stage/repodata/comps.xml <<EOF
<comps>
  <group>
    <id>glusterfs-all</id>
    <name>GlusterFS Packages</name>
    <default>true</default>
    <description>All packages of GlusterFS</description>
    <uservisible>true</uservisible>
    <packagelist>
      <packagereq type="default">glusterfs</packagereq>
      <packagereq type="default">glusterfs-devel</packagereq>
      <packagereq type="default">glusterfs-fuse</packagereq>
      <packagereq type="default">glusterfs-geo-replication</packagereq>
      <packagereq type="optional">glusterfs-rdma</packagereq>
      <packagereq type="optional">glusterfs-server</packagereq>
      <packagereq type="optional">glusterfs-debuginfo</packagereq>
      <packagereq type="optional">glusterfs-resource-agents</packagereq>
      <packagereq type="optional">glusterfs-swift</packagereq>
      <packagereq type="optional">glusterfs-swift-account</packagereq>
      <packagereq type="optional">glusterfs-swift-container</packagereq>
      <packagereq type="optional">glusterfs-swift-object</packagereq>
      <packagereq type="optional">glusterfs-swift-proxy</packagereq>
      <packagereq type="optional">glusterfs-ufo</packagereq>
    </packagelist>
  </group>
</comps>
EOF

    createrepo -g $BITS/stage/repodata/comps.xml $BITS/stage;

    mkdir $BITS/src -p;
    cp $BASEDIR/$VERSION/gluster*-$VERSION.tar.gz $BITS/src/
}

function upload_rpms()
{
    mkdir $BITS/src -p;
    cp $BASEDIR/$VERSION/gluster*-$VERSION.tar.gz $BITS/src/
}

function announce_mail()
{
    cat <<EOF | mail -s "glusterfs-$VERSION released" $EMAIL;


SRC: http://bits.gluster.org/$PFX/src/glusterfs-$VERSION.tar.gz

This release is made off $PATCHSET

-- Gluster Build System
EOF
}

function main()
{
    init_vars;

    prepare_dirs;
    get_src;
    make_tarball;
    #make_rpm;
    #stage_bits;
     #verify_tarball;
     #start_glusterfs;
     #run_tests;
     #cleanup_glusterfs;
     #upload_tarball;
    cp_tarball;
    announce_mail;
}

main "$@"
