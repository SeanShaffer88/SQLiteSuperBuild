# SuperBuild feature set — what's enabled, why, and how it's proven

Base: **SQLite 3.54.1** official amalgamation (pinned in `pins.txt`,
SHA-256 verified at fetch time). The build adds the compile-time options
below — the ones most applications want and stock binary distributions
most often leave out. Every row is verified by `test/test_superbuild.c`,
which runs in CI on the built artifacts; a feature that fails its check
fails the build.

| Flag | What it gives you | Proven by |
|---|---|---|
| `SQLITE_ENABLE_FTS5` | FTS5 full-text search (porter/ranker, prefix queries) | MATCH query returns the right document |
| `SQLITE_ENABLE_FTS4` + `FTS3_PARENTHESIS` | FTS4 tables + parenthesized FTS3/4 queries | compile-option check |
| `SQLITE_ENABLE_RTREE` | R*Tree spatial index | range query over inserted rectangles |
| `SQLITE_ENABLE_GEOPOLY` | polygon functions on top of RTREE | geopoly_area of a 10×10 square = 100 |
| `SQLITE_ENABLE_MATH_FUNCTIONS` | sqrt, pow, sin/cos, log, pi(), degrees()… | sqrt(144)+pow(2,3) = 20; degrees(pi()) = 180 |
| `SQLITE_ENABLE_DBSTAT_VTAB` | dbstat virtual table: per-table page usage (register with `CREATE VIRTUAL TABLE temp.st USING dbstat`) | row exists for a populated table |
| `SQLITE_ENABLE_COLUMN_METADATA` | sqlite3_column_database/table/origin_name APIs | compile-option check |
| `SQLITE_ENABLE_SESSION` + `PREUPDATE_HOOK` | sessions/changesets (sync, replication, undo capture) | a changeset is captured for an INSERT |
| `SQLITE_ENABLE_LOAD_EXTENSION` | runtime-loadable extensions (needed for vec0) | vec0 loads and answers a KNN query |
| `SQLITE_THREADSAFE=1` | serialized mode; safe multi-threaded use | compile-option check |

Built-in and always present (no flag needed): JSON functions and the
`->` / `->>` operators (in core since 3.38) — verified by json_extract
and operator checks.

**vec0 (sqlite-vec 0.1.9)** ships as a separate loadable extension
(`vec0.dll` / `vec0.so`), because vector search is opt-in by nature:
load it with the explicit entry point —

```sql
SELECT load_extension('./vec0', 'sqlite3_vec_init');
CREATE VIRTUAL TABLE items USING vec0(embedding float[4]);
```

## Deliberate non-changes

A SuperBuild is a **drop-in**: behavior-affecting defaults stay stock.

- No `SQLITE_DQS=0`: disabling double-quoted string literals is good
  hygiene for new SQL, but silently breaking existing queries is not
  what a drop-in does. (One-line change in flags.txt if you want it.)
- No page-size / cache-size overrides, no WAL-by-default: those are
  per-database runtime choices (`PRAGMA`), not build choices.
- No ICU: it adds a large external dependency for locale collation;
  add it downstream if you need it.

## Licenses

SQLite is public domain (see SQLITE_LICENSE.txt). sqlite-vec is
MIT/Apache-2.0 dual-licensed by its author; its amalgamation is fetched
from the project's official release. This repo's own scripts and docs
are MIT.
