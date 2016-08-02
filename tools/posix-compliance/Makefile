# $FreeBSD: src/tools/regression/fstest/Makefile,v 1.1 2007/01/17 01:42:07 pjd Exp $

.if !defined(OPSYS)
OPSYS:=	${:!uname -s!:S/-//g:S/\///g:C/^CYGWIN_.*$/Cygwin/}
.endif

.if ${OPSYS} == "FreeBSD"
#CFLAGS+=-DHAS_LCHMOD
#CFLAGS+=-DHAS_CHFLAGS
#CFLAGS+=-DHAS_LCHFLAGS
#CFLAGS+=-DHAS_TRUNCATE64
#CFLAGS+=-DHAS_STAT64
CFLAGS+=-DHAS_ACL -lacl

.elif ${OPSYS} == "NetBSD"
CFLAGS+=-DHAS_LCHMOD
CFLAGS+=-DHAS_CHFLAGS
CFLAGS+=-DHAS_LCHFLAGS
#CFLAGS+=-DHAS_TRUNCATE64
#CFLAGS+=-DHAS_STAT64
#CFLAGS+=-DHAS_ACL -lacl
.endif



all:	fstest

fstest:	fstest.c
	gcc -Wall ${CFLAGS} fstest.c -o fstest

clean:
	rm -f fstest
