#!/bin/sh
# $FreeBSD: src/tools/regression/fstest/tests/rmdir/13.t,v 1.1 2007/01/17 01:42:11 pjd Exp $

desc="rmdir returns EBUSY if the directory to be removed is the mount point for a mounted file system"

dir=`dirname $0`
. ${dir}/../misc.sh

rel=`uname -r`

case "${os}" in
FreeBSD|NetBSD)
	echo "1..3"

	n0=`namegen`

	expect 0 mkdir ${n0} 0755
	n=`mdconfig -a -n -t malloc -s 1m`
	newfs /dev/md${n} >/dev/null
	mount /dev/md${n} ${n0}
	case "${os}-${rel}" in
	NetBSD-[0-6].*)
		expect EINVAL rmdir ${n0}
		;;
	FreeBSD-*|NetBSD-*)
		expect EBUSY rmdir ${n0}
		;;
	esac
	umount /dev/md${n}
	mdconfig -d -u ${n}
	expect 0 rmdir ${n0}
	;;
*)
	quick_exit
	;;
esac
