#!/bin/sh
# Build libsqlite3 + sqlite3 shell + vec0 loadable extension (Linux/macOS).
# Requires fetch.sh first. Output: dist/
set -eu
cd "$(dirname "$0")"
[ -f vendor/src-sqlite/sqlite3.c ] || { echo "run ./fetch.sh first" >&2; exit 1; }
CC=${CC:-cc}
DEFS=$(grep -v '^#' flags.txt | grep -v '^$' | sed 's/^/-D/' | tr '\n' ' ')
mkdir -p dist
echo "flags: $DEFS"
# shellcheck disable=SC2086
$CC -O2 -fPIC -shared vendor/src-sqlite/sqlite3.c -o dist/libsqlite3.so \
    $DEFS -Ivendor/src-sqlite -lpthread -lm -ldl
# shellcheck disable=SC2086
$CC -O2 vendor/src-sqlite/shell.c vendor/src-sqlite/sqlite3.c -o dist/sqlite3 \
    $DEFS -Ivendor/src-sqlite -lpthread -lm -ldl
# shellcheck disable=SC2086
$CC -O2 -fPIC -shared vendor/src-vec/sqlite-vec.c -o dist/vec0.so \
    -Ivendor/src-sqlite -lm
ls -lh dist/
