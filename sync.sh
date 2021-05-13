#!/bin/sh
set -e

d=${0%/*}
test x"$d" != x"$0" || d=.
test ! -e "$d/local.conf" || . "$d/local.conf"

srvbase=${RSYNC_MIRROR:-rsync://mirror.leaseweb.com/openbsd}

cur_release=${INST_RELEASE:-6.8}
prev_release=$(echo $(( $(echo "$cur_release" | sed 's/\.//g') - 1)) | sed 's/.$/.&/')
releases="$prev_release $cur_release"
arch=${INST_ARCH:-amd64}
karch=${INST_ARCH:-amd64}

dirs=
rules="--exclude=index.txt"

for r in $releases; do
	dirs="$dirs syspatch/$r/$arch"
	dirs="$dirs $r/$karch"
	dirs="$dirs $r/packages/$arch"

	rules="$rules --exclude=site$(echo $r | sed 's/\.//g').tgz"
done

cd ${INST_ROOT:-/instsrc}/pub/OpenBSD
for dir in $dirs; do
	mkdir -p -- "$dir"
	rsync -aqv $rules "$srvbase/$dir/" "$dir/"
done

for r in $releases; do
	rsync -aqv "$srvbase/$r"/{src,sys,ports,xenocara}.tar.gz "$r"/
done
