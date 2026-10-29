#!/bin/sh
# Builds libohNet.so and libohNetJni.so for FreeBSD with the base system
# compiler (clang and libc++), so at run time they need only base system
# libraries: no lang/gcc, no Java package.
#
# Usage: build-native.sh OHNET_VERSION OUTDIR
#   e.g. build-native.sh 1.37.5521 out/1.37.5521
#
# Needs only a FreeBSD base system and network access. GNU make is used
# from PATH as gmake if there, or else built from source.
set -eu

[ $# -eq 2 ] || { echo "usage: $0 OHNET_VERSION OUTDIR" >&2; exit 2; }
version=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$2"
out=$(cd "$2" && pwd)
work=${WORK:-/tmp/ohnet-freebsd}
tools=$work/tools
mkdir -p "$tools/bin"

make_version=4.4.1
make_sha256=dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
# Only jni.h and jni_md.h are needed, to compile the JNI glue.
jdk_tag=jdk8u422-ga

check_sha256() {
    [ "$(sha256 -q "$1")" = "$2" ] || { echo "checksum mismatch: $1" >&2; exit 1; }
}

# GNU make.
if command -v gmake >/dev/null; then
    gmake=$(command -v gmake)
elif [ -x "$tools/bin/gmake" ]; then
    gmake=$tools/bin/gmake
else
    fetch -q -o "$work/make.tar.gz" "https://ftp.gnu.org/gnu/make/make-$make_version.tar.gz"
    check_sha256 "$work/make.tar.gz" $make_sha256
    rm -rf "$work/make-$make_version"
    tar xzf "$work/make.tar.gz" -C "$work"
    (cd "$work/make-$make_version" && ./configure -q --prefix="$tools" && ./build.sh) >/dev/null
    cp "$work/make-$make_version/make" "$tools/bin/gmake"
    gmake=$tools/bin/gmake
fi

# JNI headers.
jdk=$work/jdk
mkdir -p "$jdk/include/freebsd"
[ -f "$jdk/include/jni.h" ] || fetch -q -o "$jdk/include/jni.h" \
    "https://raw.githubusercontent.com/openjdk/jdk8u/$jdk_tag/jdk/src/share/javavm/export/jni.h"
[ -f "$jdk/include/freebsd/jni_md.h" ] || fetch -q -o "$jdk/include/freebsd/jni_md.h" \
    "https://raw.githubusercontent.com/openjdk/jdk8u/$jdk_tag/jdk/src/solaris/javavm/export/jni_md.h"

# The makefiles call gcc and g++, and python only to run patch.py on the
# bundled mDNSResponder sources.
ln -sf /usr/bin/cc "$tools/bin/gcc"
ln -sf /usr/bin/c++ "$tools/bin/g++"
cat > "$tools/bin/python" <<'EOF'
#!/bin/sh
# Stands in for "python thirdparty/python_patch/patch.py X.patch": applies
# X.patch to X with the base system patch(1).
[ "$1" = thirdparty/python_patch/patch.py ] || { echo "python: only patch.py is supported" >&2; exit 1; }
exec patch -s -N "${2%.patch}" "$2"
EOF
chmod +x "$tools/bin/python"
export PATH="$tools/bin:$PATH"

# ohNet source, with the FreeBSD patches.
src=$work/ohNet-ohNet_$version
rm -rf "$src"
fetch -q -o "$work/ohNet-$version.tar.gz" \
    "https://github.com/openhome/ohNet/archive/refs/tags/ohNet_$version.tar.gz"
tar xzf "$work/ohNet-$version.tar.gz" -C "$work"
for p in "$repo"/patches/*.patch; do
    patch -s -p1 -d "$src" < "$p"
done

mk() {
    (cd "$src" && "$gmake" freebsd=1 rsync=no cp=cp JAVA_HOME="$jdk" \
        includes_jni="-I$jdk/include -I$jdk/include/freebsd" link_jvm= \
        platform_java_cflags=-Wno-self-assign "$@")
}
# Copying the headers is not safe to run in parallel with compiling.
mk make_obj_dir copy_build_includes patch_thirdparty_sources
mk -j"$(sysctl -n hw.ncpu)" ohNetDll ohNetJni

for lib in libohNet.so libohNetJni.so; do
    strip --strip-debug -o "$out/$lib" "$src/Build/Obj/Posix/Release/$lib"
done
echo "built ohNet $version for $(uname -r) in $out"
