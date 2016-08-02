#!/bin/sh
# $FreeBSD: src/tools/regression/fstest/tests/misc.sh,v 1.1 2007/01/17 01:42:08 pjd Exp $

ntest=1

name253="_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_12"
name255="${name253}34"
name256="${name255}5"
path1021="${name255}/${name255}/${name255}/${name253}"
path1023="${path1021}/x"
path1024="${path1023}x"

echo ${dir} | egrep '^/' >/dev/null 2>&1
if [ $? -eq 0 ]; then
	maindir="${dir}/../.."
else
	maindir="`pwd`/${dir}/../.."
fi
fstest="${maindir}/fstest"
. ${maindir}/tests/conf

run_getconf()
{
	if val=$(getconf "${1}" .); then
		if [ "$value" = "undefined" ]; then
			echo "${1} is undefined"
			exit 1
		fi
	else
		echo "Failed to get ${1}"
		exit 1
	fi

	echo $val
}

name_max_val=$(run_getconf NAME_MAX)
path_max_val=$(run_getconf PATH_MAX)

name_max="_"
i=1
while test $i -lt $name_max_val ; do 
	name_max="${name_max}x"
	i=$(($i+1))
done

num_of_dirs=$(( ($path_max_val + $name_max_val) / ($name_max_val + 1) - 1 ))

long_dir="${name_max}"
i=1
while test $i -lt $num_of_dirs ; do 
	long_dir="${long_dir}/${name_max}"
	i=$(($i+1))
done
long_dir="${long_dir}/x"

too_long="${long_dir}/${name_max}"

create_too_long()
{
	mkdir -p ${long_dir}
}

unlink_too_long()
{
	rm -rf ${name_max}
}

expect()
{
	e="${1}"
	shift
	r=`${fstest} $* 2>/dev/null | tail -1`
	echo "${r}" | egrep '^'${e}'$' >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "ok ${ntest}"
	else
		echo "not ok ${ntest}"
	fi
	ntest=`expr $ntest + 1`
}

jexpect()
{
	s="${1}"
	d="${2}"
	e="${3}"
	shift 3
	r=`jail -s ${s} / fstest 127.0.0.1 /bin/sh -c "cd ${d} && ${fstest} $* 2>/dev/null" | tail -1`
	echo "${r}" | egrep '^'${e}'$' >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "ok ${ntest}"
	else
		echo "not ok ${ntest}"
	fi
	ntest=`expr $ntest + 1`
}

test_check()
{
	if [ $* ]; then
		echo "ok ${ntest}"
	else
		echo "not ok ${ntest}"
	fi
	ntest=`expr $ntest + 1`
}

namegen()
{
	echo "fstest_`dd if=/dev/urandom bs=1k count=1 2>/dev/null | md5sum  | cut -f1 -d' '`"
}

quick_exit()
{
	echo "1..1"
	echo "ok 1"
	exit 0
}

supported()
{
	case "${1}" in
	chflags)
		if [ ${os} != "FreeBSD" -o ${fs} != "UFS" ]; then
			return 1
		fi
		;;
	lchmod)
		if [ ${os} != "FreeBSD" ]; then
			return 1
		fi
		;;
	esac
	return 0
}

require()
{
	if supported ${1}; then
		return
	fi
	quick_exit
}

test "x${os}" = "xNetBSD" && {
    findvnd()
    {
    	vnd=`vnconfig -l|awk -F: '/not in use/{print $1; exit}'`
    	test "x${vnd}" = "x" && {
    		echo "no more vnd" >&2
    		exit 1;
    	}
    	echo ${vnd}
    }
    
    md2vnd()
    {
    	echo $1|sed 's|/dev/md||'
    }
    
    mdconfig()
    {
    	args=`getopt ant:s:du $*`
    	test $? -ne 0 && { echo "mdconfig usage"; exit; }
    	set -- $args
    
    	op="config"
    	size="1m"
    
    	while test $# -gt 0; do
    		case "$1" in
    			-n|-u|-a)	;;
    			-d)		op="delete" ;;
    			-t)		shift ;;
    			-s)		size=$2 shift ;;
    			--) 		shift; break ;;
    		esac
    		shift
    	done
    
    	if test "x${op}" = "xconfig" ; then
    		dd if=/dev/zero of=/tmp/$$.vnd bs=${size} count=1
    		vnd=`findvnd`
    		vnconfig ${vnd} /tmp/$$.vnd
    		echo $vnd
    	else
    		vnd=`md2vnd $1`
    		/sbin/umount -f /dev/${vnd}a 2>/dev/null
    		vnconfig -u ${vnd}
    		rm -f /tmp/$$.vnd
    	fi
    }
    
    newfs()
    {
    	args=`getopt i: $*`
    	test $? -ne 0 && { echo "newfs usage"; exit; }
    	set -- $args
    
    	inode=""
    
    	while test $# -gt 0; do
    		case "$1" in
    			-i)		inode="-i $2"; shift ;;
    			--) 		shift; break ;;
    		esac
    		shift
    	done
    
    	vnd=`md2vnd $1`
    	/sbin/newfs ${inode} /dev/r${vnd}a
    }
    
    mount()
    {
    	args=`getopt urw $*`
    	test $? -ne 0 && { echo "mount usage"; exit; }
    	set -- $args
    
    	rflag=""
    	wflag=""
    	uwflag=""
    	while test $# -gt 0; do
    		case "$1" in
    			-r)		rflag="-r" ;;
    			-w)		wflag="-w" ;;
    			-u)		uflag="-u" ;;
    			--) 		shift; break ;;
    		esac
    		shift
    	done
    
    	vnd=`md2vnd $1`
    	t=$2
    	
    	test "x${rflag}${uflag}" = "x-r-u" && {
    		t=`/sbin/mount | awk -v d="/dev/${vnd}a" '($1 == d){print $3}'` 
    		/sbin/umount -f /dev/${vnd}a
    		uflag=""
    		
    	}
    
    	/sbin/mount ${rflag} ${uflag} ${wflag} /dev/${vnd}a $t
    } 
    
    umount()
    {
    	args=`getopt f $*`
    	test $? -ne 0 && { echo "umount usage"; exit; }
    	set -- $args
    
    	fflag=""
    	while test $# -gt 0; do
    		case "$1" in
    			-f)		fflag="-r" ;;
    			--) 		shift; break ;;
    		esac
    		shift
    	done
    
    	vnd=`md2vnd $1`
    	/sbin/umount ${fflag} /dev/${vnd}a 
    }
    
    dd()
    {
    	/bin/dd msgfmt=quiet $*
    }
    
    md5sum()
    {
	md5 -n $*
    }
}

