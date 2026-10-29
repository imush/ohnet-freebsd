#!/bin/sh
# Builds ohnet.jar, the Java side of ohNet, from the same upstream source.
# It is plain Java, the same on every platform.
#
# Usage: build-jar.sh OHNET_VERSION OUTDIR
#
# Needs curl and JDK 8 (JAVA_HOME, or javac on PATH): upstream compiles for
# Java 1.6, which newer JDKs no longer target.
set -eu

[ $# -eq 2 ] || { echo "usage: $0 OHNET_VERSION OUTDIR" >&2; exit 2; }
version=$1
mkdir -p "$2"
out=$(cd "$2" && pwd)
work=${WORK:-/tmp/ohnet-freebsd}/jar-$version
java_home=${JAVA_HOME:-$(dirname "$(dirname "$(command -v javac)")")}

rm -rf "$work"
mkdir -p "$work/classes"
curl -sSfL "https://github.com/openhome/ohNet/archive/refs/tags/ohNet_$version.tar.gz" | tar xzf - -C "$work"
src=$work/ohNet-ohNet_$version

# The classes upstream puts in ohnet.jar, as listed in Common.mak.
grep -oE '^\$\(objdir\)org/[^ ]+\.class :' "$src/Common.mak" |
    sed -E 's/^\$\(objdir\)//; s/\.class :$/.java/' | sort -u > "$work/sources.txt"

cd "$src/OpenHome/Net/Bindings/Java"
"$java_home/bin/javac" -nowarn -source 1.6 -target 1.6 -bootclasspath "$java_home/jre/lib/rt.jar" \
    -classpath . -d "$work/classes" @"$work/sources.txt"
"$java_home/bin/jar" cf "$out/ohnet.jar" -C "$work/classes" org
echo "built ohnet.jar $version in $out"
