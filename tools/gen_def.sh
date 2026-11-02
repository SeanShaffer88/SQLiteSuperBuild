#!/bin/sh
# Generate a Windows .def export list from a built shared library.
#
# Usage:
#   sh tools/gen_def.sh <library> <output.def> [symbol-prefix]
#
# Examples:
#   sh tools/gen_def.sh dist/libsqlite3.so /tmp/sqlite3.def
#   sh tools/gen_def.sh dist/vec0.so /tmp/vec0.def sqlite3_vec
#
# The checked-in sqlite3.def / vec0.def are produced from the Windows
# DLLs by tools/gen_def.ps1. This script produces the same list from a
# Linux/macOS build so CI can verify that the checked-in def covers every
# symbol the library actually exports. Windows-only exports (the
# sqlite3_win32_* helpers) are present in the checked-in def but not in a
# Linux build; filter them out when comparing.
set -eu

cd "$(dirname "$0")/.."

lib=${1:?usage: gen_def.sh <library> <output.def> [symbol-prefix]}
out=${2:?usage: gen_def.sh <library> <output.def> [symbol-prefix]}
prefix=${3:-sqlite3}

[ -f "$lib" ] || { echo "no such library: $lib" >&2; exit 1; }

case "$(uname -s)" in
    Darwin)
        # macOS: global, external symbols only; names carry a leading _.
        nm -gU "$lib" | awk '{print $NF}' | sed 's/^_//'
        ;;
    *)
        # Linux and other ELF platforms.
        nm -D --defined-only "$lib" | awk '{print $NF}'
        ;;
esac | sed 's/@@.*$//' | grep "^${prefix}" | LC_ALL=C sort -u > "$out.tmp"

{
    echo "; SQLite SuperBuild export list"
    echo "; Generated from $lib by tools/gen_def.sh; do not edit by hand."
    echo "EXPORTS"
    while read -r sym; do
        if [ "$sym" = "sqlite3_version" ]; then
            echo "$sym DATA"
        else
            echo "$sym"
        fi
    done < "$out.tmp"
} > "$out"

rm -f "$out.tmp"
echo "wrote $out ($(wc -l < "$out") lines)"
