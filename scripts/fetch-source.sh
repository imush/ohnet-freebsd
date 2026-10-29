#!/bin/sh
# Fetches and unpacks the ohNet source for a version into a directory, as
# ohNet-ohNet_VERSION. A file sources/VERSION names another tarball and its
# SHA-256 (for MinimServer's own builds, which carry fixes not upstream);
# otherwise the upstream release tag is used.
#
# Usage: fetch-source.sh VERSION DIR
set -eu

[ $# -eq 2 ] || { echo "usage: $0 VERSION DIR" >&2; exit 2; }
version=$1
dir=$2
repo=$(cd "$(dirname "$0")/.." && pwd)

url="https://github.com/openhome/ohNet/archive/refs/tags/ohNet_$version.tar.gz"
sha=
if [ -f "$repo/sources/$version" ]; then
    set -- $(grep -v '^#' "$repo/sources/$version")
    url=$1
    sha=$2
fi

mkdir -p "$dir"
tarball=$dir/ohNet-$version.tar.gz
if command -v fetch >/dev/null; then
    fetch -q -o "$tarball" "$url"
else
    curl -sSfL -o "$tarball" "$url"
fi
if [ -n "$sha" ]; then
    got=$( (sha256 -q "$tarball" || sha256sum "$tarball" || shasum -a 256 "$tarball") 2>/dev/null | cut -d' ' -f1)
    [ "$got" = "$sha" ] || { echo "checksum mismatch: $url" >&2; exit 1; }
fi
rm -rf "$dir/ohNet-ohNet_$version"
tar xzf "$tarball" -C "$dir"
[ -d "$dir/ohNet-ohNet_$version" ] || { echo "$url has no ohNet-ohNet_$version" >&2; exit 1; }
