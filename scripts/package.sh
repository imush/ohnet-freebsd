#!/bin/sh
# Packs the drop-in zip under the name MinimServer looks for in libext/.
#
# Usage: package.sh ZIP_VERSION BUILDDIR OUTDIR
#   BUILDDIR holds libohNet.so, libohNetJni.so and ohnet.jar.
#   e.g. package.sh 1.37.5521.2 out/1.37.5521 dist
#   gives dist/ohnet(linux-intel)-1.37.5521.2.zip
#
# MinimServer picks the .32 or .64 library names by the JVM; both are the
# same 64-bit build here.
set -eu

[ $# -eq 3 ] || { echo "usage: $0 ZIP_VERSION BUILDDIR OUTDIR" >&2; exit 2; }
version=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
build=$(cd "$2" && pwd)
mkdir -p "$3"
out=$(cd "$3" && pwd)
name="ohnet(linux-intel)-$version.zip"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
for lib in libohNet libohNetJni; do
    cp "$build/$lib.so" "$stage/$lib.so.32"
    cp "$build/$lib.so" "$stage/$lib.so.64"
done
cp "$build/ohnet.jar" "$repo/files/LICENSE.txt" "$repo/files/module.properties" "$stage/"
rm -f "$out/$name"
(cd "$stage" && zip -q -X "$out/$name" libohNet.so.32 libohNet.so.64 libohNetJni.so.32 \
    libohNetJni.so.64 LICENSE.txt module.properties ohnet.jar)
(cd "$out" && { sha256sum "$name" 2>/dev/null || shasum -a 256 "$name"; } > "$name.sha256")
cat "$out/$name.sha256"
