/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#include <agentic_ai_lab/temporal_store.h>
#include <sqlite3.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

struct agentic_ai_lab_temporal_store { sqlite3 *db; pthread_mutex_t lock; };
static int text(const char *s) { return s && strnlen(s, 129) > 0 && strnlen(s, 129) <= 128; }
static int digest(const char *s) {
  if (!s || strnlen(s, 129) != 71 || memcmp(s, "sha256:", 7)) return 0;
  for (int i = 7; i < 71; i++)
    if (!((s[i] >= '0' && s[i] <= '9') || (s[i] >= 'a' && s[i] <= 'f'))) return 0;
  return 1;
}
static int number(uint64_t n) { return n <= INT64_MAX; }
static int sql(agentic_ai_lab_temporal_store *s, const char *q) {
  return sqlite3_exec(s->db, q, NULL, NULL, NULL) == SQLITE_OK;
}
static sqlite3_stmt *stmt(agentic_ai_lab_temporal_store *s, const char *q) {
  sqlite3_stmt *p = NULL;
  if (sqlite3_prepare_v2(s->db, q, -1, &p, NULL) != SQLITE_OK) return NULL;
  return p;
}
static void bind(sqlite3_stmt *p, int n, const char *v) {
  sqlite3_bind_text(p, n, v, -1, SQLITE_TRANSIENT);
}
static int copy(sqlite3_stmt *p, int column, char *out, size_t size) {
  const unsigned char *v = sqlite3_column_text(p, column);
  int n = sqlite3_column_bytes(p, column);
  if (!v || n < 0 || (size_t)n >= size || memchr(v, 0, (size_t)n)) return 0;
  memcpy(out, v, (size_t)n); out[n] = 0; return 1;
}
static int eq(sqlite3_stmt *p, int c, const char *v) {
  const unsigned char *x = sqlite3_column_text(p, c);
  return x && sqlite3_column_bytes(p, c) == (int)strlen(v) && !strcmp((const char *)x, v);
}
static int finish(agentic_ai_lab_temporal_store *s, int code) {
  if (!code) { if (!sql(s, "COMMIT")) { sql(s, "ROLLBACK"); return 6; } }
  else sql(s, "ROLLBACK");
  return code;
}
int32_t agentic_ai_lab_temporal_store_open(const char *path, agentic_ai_lab_temporal_store **out) {
  if (!out || *out || !path || path[0] != '/' || strnlen(path, 4097) > 4096) return 1;
  agentic_ai_lab_temporal_store *s = calloc(1, sizeof(*s));
  if (!s) return 6;
  pthread_mutex_init(&s->lock, NULL);
  if (sqlite3_open_v2(path, &s->db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
    agentic_ai_lab_temporal_store_close(s); return 6;
  }
  sqlite3_busy_timeout(s->db, 1000);
  if (!sql(s, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA trusted_schema=OFF; BEGIN IMMEDIATE;"
      "CREATE TABLE IF NOT EXISTS temporal_meta(id INTEGER PRIMARY KEY CHECK(id=1), version INTEGER, identity TEXT);"
      "INSERT OR IGNORE INTO temporal_meta VALUES(1,1,lower(hex(randomblob(32))));"
      "CREATE TABLE IF NOT EXISTS temporal_sources(source TEXT PRIMARY KEY,digest TEXT NOT NULL,generation INTEGER NOT NULL);"
      "CREATE TABLE IF NOT EXISTS temporal_authorities(subject TEXT,scope TEXT,policy TEXT NOT NULL,authority TEXT NOT NULL,"
      "fence INTEGER NOT NULL,enabled INTEGER NOT NULL,PRIMARY KEY(subject,scope));"
      "CREATE TABLE IF NOT EXISTS temporal_pointers(subject TEXT,scope TEXT,version INTEGER NOT NULL,selected TEXT NOT NULL,PRIMARY KEY(subject,scope));"
      "CREATE TABLE IF NOT EXISTS temporal_commits(key TEXT PRIMARY KEY,request_digest TEXT NOT NULL,admission TEXT NOT NULL,"
      "subject TEXT NOT NULL,scope TEXT NOT NULL,policy TEXT NOT NULL,revision TEXT NOT NULL,proof TEXT NOT NULL,"
      "source_digest TEXT NOT NULL,authority TEXT NOT NULL,previous_version INTEGER NOT NULL,version INTEGER NOT NULL,"
      "fence INTEGER NOT NULL,generation INTEGER NOT NULL);")) {
    sql(s, "ROLLBACK"); agentic_ai_lab_temporal_store_close(s); return 6;
  }
  sqlite3_stmt *p = stmt(s, "SELECT version,identity FROM temporal_meta WHERE id=1");
  int ok = p && sqlite3_step(p) == SQLITE_ROW && sqlite3_column_int(p, 0) == 1 && sqlite3_column_bytes(p, 1) == 64;
  sqlite3_finalize(p);
  if (!ok || !sql(s, "COMMIT")) { sql(s, "ROLLBACK"); agentic_ai_lab_temporal_store_close(s); return 6; }
  *out = s; return 0;
}
void agentic_ai_lab_temporal_store_close(agentic_ai_lab_temporal_store *s) {
  if (!s) return;
  sqlite3_close(s->db); pthread_mutex_destroy(&s->lock); free(s);
}
int32_t agentic_ai_lab_temporal_store_source(agentic_ai_lab_temporal_store *s, const char *source, const char *value, uint64_t generation) {
  if (!s || !text(source) || !digest(value) || !number(generation)) return 1;
  pthread_mutex_lock(&s->lock);
  int code = 6;
  sqlite3_stmt *p = NULL;
  if (!sql(s, "BEGIN IMMEDIATE")) goto done;
  p = stmt(s, "SELECT digest,generation FROM temporal_sources WHERE source=?1");
  if (!p) goto transaction;
  bind(p, 1, source);
  int step = sqlite3_step(p);
  if (step == SQLITE_ROW) {
    uint64_t old = (uint64_t)sqlite3_column_int64(p, 1);
    if (generation < old || (generation == old && !eq(p, 0, value))) { code = 4; goto transaction; }
  } else if (step != SQLITE_DONE) goto transaction;
  sqlite3_finalize(p);
  p = stmt(s, "INSERT INTO temporal_sources VALUES(?1,?2,?3) ON CONFLICT(source) DO UPDATE SET digest=excluded.digest,generation=excluded.generation");
  if (!p) goto transaction;
  bind(p, 1, source); bind(p, 2, value); sqlite3_bind_int64(p, 3, (sqlite3_int64)generation);
  if (sqlite3_step(p) == SQLITE_DONE) code = 0;
transaction:
  sqlite3_finalize(p); p = NULL; code = finish(s, code);
done:
  sqlite3_finalize(p); pthread_mutex_unlock(&s->lock); return code;
}
int32_t agentic_ai_lab_temporal_store_authorize(agentic_ai_lab_temporal_store *s, const char *subject, const char *scope,
    const char *policy, const char *authority, uint64_t fence, int32_t enabled) {
  if (!s || !text(subject) || !text(scope) || !text(policy) || !text(authority) || !fence || !number(fence) || (enabled != 0 && enabled != 1)) return 1;
  pthread_mutex_lock(&s->lock);
  int code = 6; sqlite3_stmt *p = NULL;
  if (!sql(s, "BEGIN IMMEDIATE")) goto done;
  p = stmt(s, "SELECT policy,authority,fence,enabled FROM temporal_authorities WHERE subject=?1 AND scope=?2");
  if (!p) goto transaction;
  bind(p, 1, subject); bind(p, 2, scope);
  int step = sqlite3_step(p);
  if (step == SQLITE_ROW) {
    uint64_t old = (uint64_t)sqlite3_column_int64(p, 2);
    if (fence < old || (fence == old && (!eq(p, 0, policy) || !eq(p, 1, authority) || sqlite3_column_int(p, 3) != enabled))) {
      code = 3; goto transaction;
    }
  } else if (step != SQLITE_DONE) goto transaction;
  sqlite3_finalize(p);
  p = stmt(s, "INSERT INTO temporal_authorities VALUES(?1,?2,?3,?4,?5,?6) ON CONFLICT(subject,scope) DO UPDATE SET "
      "policy=excluded.policy,authority=excluded.authority,fence=excluded.fence,enabled=excluded.enabled");
  if (!p) goto transaction;
  bind(p, 1, subject); bind(p, 2, scope); bind(p, 3, policy); bind(p, 4, authority);
  sqlite3_bind_int64(p, 5, (sqlite3_int64)fence); sqlite3_bind_int(p, 6, enabled);
  if (sqlite3_step(p) == SQLITE_DONE) code = 0;
transaction:
  sqlite3_finalize(p); p = NULL; code = finish(s, code);
done:
  sqlite3_finalize(p); pthread_mutex_unlock(&s->lock); return code;
}
static int pointer(agentic_ai_lab_temporal_store *s, const char *subject, const char *scope, uint64_t *version, char selected[129]) {
  sqlite3_stmt *p = stmt(s, "SELECT version,selected FROM temporal_pointers WHERE subject=?1 AND scope=?2");
  if (!p) return 6;
  bind(p, 1, subject); bind(p, 2, scope);
  int step = sqlite3_step(p), code = 6;
  if (step == SQLITE_DONE) { *version = 0; selected[0] = 0; code = 0; }
  else if (step == SQLITE_ROW && sqlite3_column_int64(p, 0) >= 0 && copy(p, 1, selected, 129)) {
    *version = (uint64_t)sqlite3_column_int64(p, 0); code = 0;
  }
  sqlite3_finalize(p); return code;
}
int32_t agentic_ai_lab_temporal_store_pointer(agentic_ai_lab_temporal_store *s, const char *subject, const char *scope, uint64_t *version, char selected[129]) {
  if (!s || !text(subject) || !text(scope) || !version || !selected) return 1;
  pthread_mutex_lock(&s->lock); int code = pointer(s, subject, scope, version, selected);
  pthread_mutex_unlock(&s->lock); return code;
}
static int receipt(agentic_ai_lab_temporal_store *s, const char *key, agentic_ai_lab_temporal_commit_receipt *out) {
  sqlite3_stmt *p = stmt(s, "SELECT m.identity,c.key,c.request_digest,c.admission,c.subject,c.scope,c.policy,c.revision,c.proof,"
    "c.source_digest,c.authority,c.previous_version,c.version,c.fence,c.generation FROM temporal_commits c JOIN temporal_meta m ON m.id=1 WHERE c.key=?1");
  if (!p) return 6;
  bind(p, 1, key);
  int step = sqlite3_step(p), code = 6;
  if (step == SQLITE_DONE) code = 7;
  else if (step == SQLITE_ROW) {
    memset(out, 0, sizeof(*out));
    char *fields[] = {out->store_identity,out->key,out->request_digest,out->admission,out->subject,out->scope,
                      out->policy,out->revision,out->proof,out->source_digest,out->authority};
    int valid = 1;
    for (int i=0; i<11; i++) if (!copy(p,i,fields[i],i==0?65:129)) valid=0;
    for (int i=11; i<15; i++) if (sqlite3_column_int64(p,i)<0) valid=0;
    out->previous_version=(uint64_t)sqlite3_column_int64(p,11); out->version=(uint64_t)sqlite3_column_int64(p,12);
    out->authorization_fence=(uint64_t)sqlite3_column_int64(p,13); out->source_generation=(uint64_t)sqlite3_column_int64(p,14);
    if (valid) code=0;
  }
  sqlite3_finalize(p); return code;
}
int32_t agentic_ai_lab_temporal_store_receipt(agentic_ai_lab_temporal_store *s, const char *key, agentic_ai_lab_temporal_commit_receipt *out) {
  if (!s || !text(key) || !out) return 1;
  pthread_mutex_lock(&s->lock); int code = receipt(s,key,out); pthread_mutex_unlock(&s->lock); return code;
}
int32_t agentic_ai_lab_temporal_store_commit(agentic_ai_lab_temporal_store *s, const agentic_ai_lab_temporal_basis *b,
    const char *key, const char *request, uint64_t expected, const char *predecessor, uint64_t fence,
    agentic_ai_lab_temporal_commit_receipt *out) {
  if (!s || !b || !out || !text(key) || !digest(request) || !number(expected) || !number(fence) || !number(b->generation) ||
      !predecessor || strnlen(predecessor,129)>128 || !digest(b->admission) || !text(b->source) || !digest(b->source_digest) ||
      !text(b->subject) || !text(b->scope) || !text(b->policy) || !digest(b->revision) || !digest(b->proof)) return 1;
  pthread_mutex_lock(&s->lock);
  int code=6; sqlite3_stmt *p=NULL;
  if (!sql(s,"BEGIN IMMEDIATE")) goto done;
  code=receipt(s,key,out);
  if (!code) {
    if (strcmp(out->request_digest,request) || strcmp(out->admission,b->admission) || out->previous_version!=expected ||
        out->authorization_fence!=fence || expected!=0 || predecessor[0] ||
        strcmp(out->subject,b->subject) || strcmp(out->scope,b->scope) || strcmp(out->policy,b->policy) ||
        strcmp(out->revision,b->revision) || strcmp(out->proof,b->proof) || strcmp(out->source_digest,b->source_digest) ||
        out->source_generation!=b->generation) code=5;
    goto transaction;
  }
  if (code!=7) goto transaction;
  code=6;
  p=stmt(s,"SELECT digest,generation FROM temporal_sources WHERE source=?1");
  if (!p) goto transaction;
  bind(p,1,b->source);
  int step=sqlite3_step(p);
  if (step==SQLITE_DONE || (step==SQLITE_ROW && (!eq(p,0,b->source_digest) || (uint64_t)sqlite3_column_int64(p,1)!=b->generation))) {
    code=4; goto transaction;
  }
  if (step!=SQLITE_ROW) goto transaction;
  sqlite3_finalize(p);
  p=stmt(s,"SELECT policy,authority,fence,enabled FROM temporal_authorities WHERE subject=?1 AND scope=?2");
  if (!p) goto transaction;
  bind(p,1,b->subject); bind(p,2,b->scope);
  step=sqlite3_step(p);
  if (step==SQLITE_DONE || (step==SQLITE_ROW && (!eq(p,0,b->policy) || (uint64_t)sqlite3_column_int64(p,2)!=fence || sqlite3_column_int(p,3)!=1))) {
    code=3; goto transaction;
  }
  if (step!=SQLITE_ROW) goto transaction;
  char authority[129];
  if (!copy(p,1,authority,sizeof(authority))) goto transaction;
  sqlite3_finalize(p); p=NULL;
  uint64_t current; char selected[129];
  if (pointer(s,b->subject,b->scope,&current,selected)) goto transaction;
  if (current!=expected || strcmp(selected,predecessor) || expected!=0 || predecessor[0]) { code=2; goto transaction; }
  p=stmt(s,"INSERT INTO temporal_pointers VALUES(?1,?2,1,?3)");
  if (!p) goto transaction;
  bind(p,1,b->subject); bind(p,2,b->scope); bind(p,3,b->revision);
  if (sqlite3_step(p)!=SQLITE_DONE) goto transaction;
  sqlite3_finalize(p);
  p=stmt(s,"INSERT INTO temporal_commits VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,0,1,?11,?12)");
  if (!p) goto transaction;
  const char *values[]={key,request,b->admission,b->subject,b->scope,b->policy,b->revision,b->proof,b->source_digest,authority};
  for (int i=0;i<10;i++) bind(p,i+1,values[i]);
  sqlite3_bind_int64(p,11,(sqlite3_int64)fence); sqlite3_bind_int64(p,12,(sqlite3_int64)b->generation);
  if (sqlite3_step(p)!=SQLITE_DONE) goto transaction;
  sqlite3_finalize(p); p=NULL; code=receipt(s,key,out);
transaction:
  sqlite3_finalize(p); p=NULL; code=finish(s,code);
done:
  sqlite3_finalize(p); pthread_mutex_unlock(&s->lock); return code;
}
