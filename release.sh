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

function cp_tarball()
{
    mkdir $BITS/src -p;
    cp $BASEDIR/$VERSION/gluster*-$VERSION.tar.gz $BITS/src/
    sha256sum $BITS/src/gluster*-$VERSION.tar.gz > $BITS/src/gluster*-$VERSION.sha256sum
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
    cp_tarball;
    announce_mail;
}

main "$@"
