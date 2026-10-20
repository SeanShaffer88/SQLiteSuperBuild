#!/bin/sh
# Download the pinned upstream sources into vendor/ and verify SHA-256.
set -eu
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./pins.txt
mkdir -p vendor

fetch() {
    url="$1"; file="$2"; want="$3"
    if [ ! -f "vendor/$file" ]; then
        echo "downloading $url"
        curl -fL "$url" -o "vendor/$file"
    fi
    got=$(sha256sum "vendor/$file" | awk '{print $1}')
    # sha256sum exists on Linux; macOS fallback:
    if [ -z "$got" ]; then got=$(shasum -a 256 "vendor/$file" | awk '{print $1}'); fi
    if [ "$got" != "$want" ]; then
        echo "SHA-256 MISMATCH for $file" >&2
        echo "  pinned: $want" >&2
        echo "  actual: $got" >&2
        exit 1
    fi
    echo "verified $file ($got)"
}

fetch "$SQLITE_URL" "$SQLITE_AMALGAMATION.zip" "$SQLITE_SHA256"
fetch "$SQLITE_VEC_URL" "sqlite-vec-$SQLITE_VEC_VERSION-amalgamation.zip" "$SQLITE_VEC_SHA256"

rm -rf vendor/src-sqlite vendor/src-vec
mkdir -p vendor/src-sqlite vendor/src-vec
unzip -qo "vendor/$SQLITE_AMALGAMATION.zip" -d vendor/tmp-sqlite
mv "vendor/tmp-sqlite/$SQLITE_AMALGAMATION"/* vendor/src-sqlite/
rm -rf vendor/tmp-sqlite
unzip -qo "vendor/sqlite-vec-$SQLITE_VEC_VERSION-amalgamation.zip" -d vendor/src-vec
echo "sources ready in vendor/src-sqlite and vendor/src-vec"
