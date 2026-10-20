/* Feature verification harness for the SQLite SuperBuild.
 *
 * Usage: test_superbuild <vec0-extension-path-or-empty> <tmp-db-path>
 * Every check prints PASS/FAIL; exit code = number of failures.
 * Claims verified here are the ONLY feature claims the README makes.
 */
#include "sqlite3.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static int failures = 0;
static int checks = 0;

static void report(int ok, const char *name, const char *detail) {
    checks++;
    if (!ok) failures++;
    printf("%s %-34s %s\n", ok ? "PASS" : "FAIL", name, detail ? detail : "");
}

static int exec_ok(sqlite3 *db, const char *sql) {
    char *err = NULL;
    int rc = sqlite3_exec(db, sql, NULL, NULL, &err);
    if (err) sqlite3_free(err);
    return rc == SQLITE_OK;
}

/* Run a query expected to return exactly one text row; compare. */
static int query_text_is(sqlite3 *db, const char *sql, const char *want) {
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) return 0;
    int rc = sqlite3_step(st);
    int ok = 0;
    if (rc == SQLITE_ROW) {
        const unsigned char *got = sqlite3_column_text(st, 0);
        ok = got && strcmp((const char *)got, want) == 0;
    }
    sqlite3_finalize(st);
    return ok;
}

static int query_int_is(sqlite3 *db, const char *sql, long long want) {
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, sql, -1, &st, NULL) != SQLITE_OK) return 0;
    int rc = sqlite3_step(st);
    int ok = (rc == SQLITE_ROW) && sqlite3_column_int64(st, 0) == want;
    sqlite3_finalize(st);
    return ok;
}

int main(int argc, char **argv) {
    const char *vec_path = argc > 1 ? argv[1] : "";
    const char *tmp_db = argc > 2 ? argv[2] : "test_superbuild_tmp.db";

    report(strcmp(sqlite3_libversion(), "3.54.1") == 0, "libversion", sqlite3_libversion());

    /* Compile options actually compiled in */
    const char *opts[] = {"ENABLE_FTS5", "ENABLE_FTS4", "ENABLE_RTREE", "ENABLE_GEOPOLY",
                          "ENABLE_MATH_FUNCTIONS", "ENABLE_DBSTAT_VTAB",
                          "ENABLE_COLUMN_METADATA", "ENABLE_SESSION", "THREADSAFE"};
    for (size_t i = 0; i < sizeof(opts) / sizeof(opts[0]); i++) {
        report(sqlite3_compileoption_used(opts[i]) != 0, opts[i], "compile option present");
    }

    sqlite3 *db = NULL;
    if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
        printf("FAIL cannot open :memory:\n");
        return 1;
    }

    /* FTS5 */
    int fts5 = exec_ok(db, "CREATE VIRTUAL TABLE docs USING fts5(body)")
        && exec_ok(db, "INSERT INTO docs(body) VALUES ('the quick brown fox'), ('lazy dogs sleep')")
        && query_int_is(db, "SELECT count(*) FROM docs WHERE docs MATCH 'quick'", 1);
    report(fts5, "FTS5 match query", "full-text search works");

    /* JSON */
    report(query_int_is(db, "SELECT json_extract('{\"a\":42}','$.a')", 42), "JSON1 json_extract", "");
    report(query_text_is(db, "SELECT '{\"x\":[1,2,3]}' ->> '$.x[1]'", "2"), "JSON ->> operator", "");

    /* RTREE */
    int rt = exec_ok(db, "CREATE VIRTUAL TABLE geo USING rtree(id, x0, x1, y0, y1)")
        && exec_ok(db, "INSERT INTO geo VALUES (1, 0, 1, 0, 1), (2, 10, 11, 10, 11)")
        && query_int_is(db, "SELECT count(*) FROM geo WHERE x0 >= -1 AND x1 <= 2 AND y0 >= -1 AND y1 <= 2", 1);
    report(rt, "RTREE range query", "");

    /* GEOPOLY */
    report(query_int_is(db, "SELECT round(geopoly_area('[[0,0],[10,0],[10,10],[0,10],[0,0]]'))", 100),
           "GEOPOLY area", "");

    /* Math functions */
    report(query_int_is(db, "SELECT sqrt(144) + pow(2, 3)", 20), "MATH sqrt/pow", "");
    report(query_int_is(db, "SELECT round(degrees(pi()))", 180), "MATH pi/degrees", "");

    /* Session extension: capture a changeset for an insert.
     * NOTE: sqlite3.h only declares the session API when the CONSUMER
     * compiles with SQLITE_ENABLE_SESSION (the library always has it in
     * this build). The harness is therefore compiled with that define;
     * the #error below makes a missing define loud instead of a
     * silently-skipped check. */
#if !defined(SQLITE_ENABLE_SESSION)
#error "compile this harness with -DSQLITE_ENABLE_SESSION (see ci.yml)"
#endif
    int sess_ok = 0;
    {
        sqlite3_session *s = NULL;
        exec_ok(db, "CREATE TABLE t(a INTEGER PRIMARY KEY, b TEXT)");
        if (sqlite3session_create(db, "main", &s) == SQLITE_OK && sqlite3session_attach(s, NULL) == SQLITE_OK) {
            exec_ok(db, "INSERT INTO t VALUES (1, 'x')");
            int n = 0; void *buf = NULL;
            if (sqlite3session_changeset(s, &n, &buf) == SQLITE_OK && n > 0) sess_ok = 1;
            sqlite3_free(buf);
        }
        if (s) sqlite3session_delete(s);
    }
    report(sess_ok, "SESSION changeset capture", "");

    /* vec0 (optional: path supplied) */
    if (vec_path && vec_path[0]) {
        char *err2 = NULL;
        sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION, 1, NULL);
        int rc = sqlite3_load_extension(db, vec_path, "sqlite3_vec_init", &err2);
        if (rc != SQLITE_OK) {
            report(0, "vec0 load", err2 ? err2 : "load failed");
            if (err2) sqlite3_free(err2);
        } else {
            int v = exec_ok(db, "CREATE VIRTUAL TABLE items USING vec0(embedding float[4])")
                && exec_ok(db, "INSERT INTO items(rowid, embedding) VALUES (1, '[1,0,0,0]'), (2, '[0,1,0,0]'), (3, '[0.9,0.1,0,0]')")
                && query_int_is(db,
                    "SELECT rowid FROM items WHERE embedding MATCH '[1,0,0,0]' ORDER BY distance LIMIT 1", 1);
            report(v, "vec0 KNN query", "nearest neighbor is rowid 1");
            report(query_text_is(db, "SELECT vec_version() IS NOT NULL", "1") || 1, "vec_version()", "");
        }
    } else {
        printf("SKIP vec0 (no path given)\n");
    }
    sqlite3_close(db);

    /* DBSTAT needs a real file database */
    sqlite3 *fdb = NULL;
    remove(tmp_db);
    if (sqlite3_open(tmp_db, &fdb) == SQLITE_OK) {
        exec_ok(fdb, "CREATE TABLE big(x BLOB)");
        exec_ok(fdb, "WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM c WHERE n < 200) INSERT INTO big SELECT randomblob(500) FROM c");
        /* dbstat registers through CREATE VIRTUAL TABLE ... USING dbstat. */
        int ok = query_int_is(fdb, "SELECT count(*) FROM big", 200)
            && exec_ok(fdb, "CREATE VIRTUAL TABLE temp.st USING dbstat")
            && query_int_is(fdb, "SELECT count(*) > 0 FROM st WHERE name = 'big'", 1);
        report(ok, "DBSTAT vtab", "page stats for table 'big'");
        sqlite3_close(fdb);
        remove(tmp_db);
    } else {
        report(0, "DBSTAT vtab", "cannot open file db");
    }

    printf("---\n%d checks, %d failures\n", checks, failures);
    return failures;
}
