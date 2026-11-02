# SQLite SuperBuild

**A drop-in `sqlite3.dll` with everything switched on** — FTS5 full-text
search, R*Tree + Geopoly, math functions, DBSTAT, sessions/changesets,
column metadata — plus the `sqlite3` shell and the **vec0** vector-search
extension, all built from one pinned, hash-verified source.

#4 in the Windows DLL Collection (after WinRecovery, FastSearch,
ArchiveKit).

## Why

The SQLite most programs end up with is whatever a package manager or a
random download provided — usually built with conservative defaults that
leave out exactly the features modern tools reach for: full-text search,
spatial indexes, JSON (present), math functions, vector search. The
SuperBuild is one reproducible answer: fetch the official amalgamation
at a pinned version, verify its SHA-256, compile it with the curated
flag set in `flags.txt`, and prove — with a test harness, not a promise —
that every feature works in the produced DLL.

## Get it

Download the CI artifact (`sqlite-superbuild-windows-x64`) from the
Actions tab, or build it yourself:

```powershell
./fetch.ps1    # downloads SQLite 3.54.1 + sqlite-vec 0.1.9, verifies SHA-256
./build.ps1    # needs a Visual Studio developer prompt (cl on PATH)
# dist/: sqlite3.dll, sqlite3.lib, sqlite3.exe, vec0.dll
```

Linux/macOS: `./fetch.sh && ./build.sh` produces `libsqlite3.so`,
`sqlite3`, and `vec0.so`.

The release zip also carries `sqlite3.def` and `vec0.def` — export
lists for toolchains that cannot generate an import library from a DLL
on their own. With MinGW-w64:

```sh
dlltool -d sqlite3.def -l libsqlite3.a
dlltool -d vec0.def -l libvec0.a
```

With LLVM: `llvm-dlltool -d sqlite3.def -l libsqlite3.a`. CI
regenerates both defs from the built DLLs and fails if the checked-in
copies are stale.

## Feature set

Full matrix with rationale in [docs/FEATURES.md](docs/FEATURES.md).
Highlights: FTS5 + FTS4, RTREE + GEOPOLY, MATH_FUNCTIONS, DBSTAT_VTAB,
SESSION + PREUPDATE_HOOK, COLUMN_METADATA, loadable extensions,
THREADSAFE=1. JSON is in core. vec0 ships separately (opt-in):
`SELECT load_extension('./vec0', 'sqlite3_vec_init');`

**Drop-in rule:** no behavior-changing defaults versus stock SQLite —
feature-enabling flags only, so existing databases and queries behave
identically.

## Verification

`test/test_superbuild.c` is the contract: version pin, every compile
option, and a live functional check per feature (FTS5 MATCH, JSON
extract + `->>`, RTREE range query, geopoly_area, math functions,
session changeset capture, dbstat on a file database, vec0 KNN). CI
runs it against the built artifacts on Windows and Linux. The README
claims nothing the harness does not check.

The export lists are part of the contract too: CI regenerates
`sqlite3.def` / `vec0.def` from the built DLLs and compares them to the
checked-in files, so a flag change cannot silently alter the public
ABI.

## Updating SQLite

Bump `pins.txt` (version + SHA-256 together), run fetch + build +
harness, regenerate the defs (`pwsh tools/gen_def.ps1 ...` on Windows,
`sh tools/gen_def.sh ...` elsewhere), commit the pins and the defs
together, then tag. The pins are the supply chain: if the hash does
not match, the fetch refuses to proceed.

## License

This repo's scripts and docs: MIT. SQLite itself is public domain;
sqlite-vec is MIT/Apache-2.0 — see SQLITE_LICENSE.txt.
