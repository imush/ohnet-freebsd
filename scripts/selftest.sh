#!/bin/sh
# Checks a drop-in zip on this machine without MinimServer: runs ohNet's own
# Java test, which publishes a UPnP device and uses it from a control point
# in the same process (discovery, actions and event subscriptions).
#
# Usage: selftest.sh ZIP [JAVA]
#   JAVA defaults to java on PATH.
set -eu

[ $# -ge 1 ] || { echo "usage: $0 ZIP [JAVA]" >&2; exit 2; }
zip=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
java=${2:-java}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
unzip -q "$zip" libohNet.so.64 libohNetJni.so.64 ohnet.jar
mv libohNet.so.64 libohNet.so
mv libohNetJni.so.64 libohNetJni.so

"$java" -version 2>&1 | head -1
LD_LIBRARY_PATH=$dir timeout 300 "$java" -Djava.library.path="$dir" -cp ohnet.jar \
    org.openhome.net.device.tests.TestDvDevice > test.log 2>&1 || { cat test.log; exit 1; }
cat test.log
grep -q 'TestDvDeviceJava - completed' test.log
echo "selftest passed on FreeBSD $(freebsd-version)"
