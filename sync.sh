#!/bin/sh
set -e

srvbase=${RSYNC_MIRROR:-rsync://mirror.leaseweb.com/openbsd}

prev_release=$(echo $(( $(uname -r | sed 's/\.//g') - 1)) | sed 's/.$/.&/')
releases="$prev_release $(uname -r)"

dirs=
rules="--exclude=index.txt"

for r in $releases; do
	dirs="$dirs syspatch/$r/$(uname -m)"
	dirs="$dirs $r/$(uname -m)"
	dirs="$dirs $r/packages/$(uname -p)"

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
