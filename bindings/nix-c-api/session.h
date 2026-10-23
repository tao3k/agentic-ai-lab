/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
 * Product-owned serial evaluator bridge. Never installed into Yuanxu.
 */
#include <nix_api_expr.h>
#include <nix_api_value.h>
#include <nix_api_flake.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/resource.h>
#include <dlfcn.h>

enum { AGENTIC_AI_LAB_INIT, AGENTIC_AI_LAB_STORE, AGENTIC_AI_LAB_STATE, AGENTIC_AI_LAB_SETTINGS, AGENTIC_AI_LAB_LOCK, AGENTIC_AI_LAB_OUTPUTS,
       AGENTIC_AI_LAB_APPLY, AGENTIC_AI_LAB_RESULT, AGENTIC_AI_LAB_PHASES };
/* Qualification-only counters. GC symbols belong to the already loaded Nix
 * dependency; no second collector is loaded. Thread CPU excludes helper threads.
 * rusage block counts are not read(2) counts and may be zero for cached I/O. */
enum { AGENTIC_AI_LAB_THREAD, AGENTIC_AI_LAB_GC_MS, AGENTIC_AI_LAB_GC_CYCLES, AGENTIC_AI_LAB_ALLOCATED, AGENTIC_AI_LAB_MINOR, AGENTIC_AI_LAB_MAJOR,
       AGENTIC_AI_LAB_INBLOCK, AGENTIC_AI_LAB_OUTBLOCK, AGENTIC_AI_LAB_VOLUNTARY, AGENTIC_AI_LAB_INVOLUNTARY, AGENTIC_AI_LAB_METRICS };
static int agentic_ai_lab_nix_profile;
static int (*agentic_ai_lab_gc_incremental_mode)(void);
static unsigned long (*agentic_ai_lab_gc_time)(void), (*agentic_ai_lab_gc_cycles)(void);
static size_t (*agentic_ai_lab_gc_allocated)(void);
static int agentic_ai_lab_nix_profile_start(void)
{
    agentic_ai_lab_nix_profile = getenv("AGENTIC_AI_LAB_NIX_PROFILE_METRICS") != NULL;
    if (!agentic_ai_lab_nix_profile) return 1;
    if (agentic_ai_lab_gc_time && agentic_ai_lab_gc_cycles && agentic_ai_lab_gc_allocated) return 1;
    void (*start)(void) = dlsym(RTLD_DEFAULT, "GC_start_performance_measurement");
    agentic_ai_lab_gc_time = dlsym(RTLD_DEFAULT, "GC_get_full_gc_total_time");
    agentic_ai_lab_gc_cycles = dlsym(RTLD_DEFAULT, "GC_get_gc_no");
    agentic_ai_lab_gc_allocated = dlsym(RTLD_DEFAULT, "GC_get_total_bytes");
    agentic_ai_lab_gc_incremental_mode = dlsym(RTLD_DEFAULT, "GC_is_incremental_mode");
    if (!start || !agentic_ai_lab_gc_time || !agentic_ai_lab_gc_cycles || !agentic_ai_lab_gc_allocated || !agentic_ai_lab_gc_incremental_mode) return 0;
    start();
    return 1;
}
typedef struct { double wall, cpu, metrics[AGENTIC_AI_LAB_METRICS]; } agentic_ai_lab_nix_clock;
static agentic_ai_lab_nix_clock agentic_ai_lab_nix_now(void)
{
    struct timespec wall, cpu;
    clock_gettime(CLOCK_MONOTONIC, &wall);
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpu);
    agentic_ai_lab_nix_clock result = {wall.tv_sec + wall.tv_nsec * 1e-9,
                           cpu.tv_sec + cpu.tv_nsec * 1e-9, {0}};
    if (agentic_ai_lab_nix_profile) {
        struct timespec thread;
        struct rusage usage;
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &thread);
        getrusage(RUSAGE_SELF, &usage);
        double metrics[AGENTIC_AI_LAB_METRICS] = {
            thread.tv_sec + thread.tv_nsec * 1e-9,
            agentic_ai_lab_gc_time(), agentic_ai_lab_gc_cycles(), agentic_ai_lab_gc_allocated(),
            usage.ru_minflt, usage.ru_majflt, usage.ru_inblock, usage.ru_oublock,
            usage.ru_nvcsw, usage.ru_nivcsw};
        memcpy(result.metrics, metrics, sizeof metrics);
    }
    return result;
}

typedef struct {
    nix_c_context *ctx;
    Store *store;
    EvalState *state;
    nix_value *function;
    nix_value *pending;
    nix_fetchers_settings *fetchers;
    nix_flake_settings *flakes;
    nix_flake_reference *reference;
    nix_flake_lock_flags *lock_flags;
    char *output;
    char *error;
    unsigned calls;
    double wall[AGENTIC_AI_LAB_PHASES], cpu[AGENTIC_AI_LAB_PHASES];
    unsigned phase_calls[AGENTIC_AI_LAB_PHASES];
    double metrics[AGENTIC_AI_LAB_PHASES][AGENTIC_AI_LAB_METRICS];
} agentic_ai_lab_nix_session;

static void agentic_ai_lab_nix_elapsed(agentic_ai_lab_nix_session *s, int phase, agentic_ai_lab_nix_clock start)
{
    agentic_ai_lab_nix_clock end = agentic_ai_lab_nix_now();
    s->wall[phase] += end.wall - start.wall;
    s->cpu[phase] += end.cpu - start.cpu;
    if (agentic_ai_lab_nix_profile)
        for (int i = 0; i < AGENTIC_AI_LAB_METRICS; ++i)
            s->metrics[phase][i] += end.metrics[i] - start.metrics[i];
    ++s->phase_calls[phase];
}
static double agentic_ai_lab_nix_seconds(agentic_ai_lab_nix_session *s, int phase, int cpu)
{
    if (phase < 0 || phase >= AGENTIC_AI_LAB_PHASES) return -1;
    return cpu ? s->cpu[phase] : s->wall[phase];
}
static double agentic_ai_lab_nix_metric(agentic_ai_lab_nix_session *s, int phase, int metric)
{
    return phase >= 0 && phase < AGENTIC_AI_LAB_PHASES && metric >= 0 && metric < AGENTIC_AI_LAB_METRICS
        ? s->metrics[phase][metric] : -1;
}
static unsigned agentic_ai_lab_nix_phase_calls(agentic_ai_lab_nix_session *s, int phase)
{
    return phase >= 0 && phase < AGENTIC_AI_LAB_PHASES ? s->phase_calls[phase] : 0;
}

static void agentic_ai_lab_nix_capture(const char *bytes, unsigned n, void *data)
{
    char **destination = data;
    free(*destination);
    *destination = malloc((size_t)n + 1);
    if (*destination) {
        memcpy(*destination, bytes, n);
        (*destination)[n] = 0;
    }
}

static int agentic_ai_lab_nix_status(agentic_ai_lab_nix_session *s)
{
    if (nix_err_code(s->ctx) == NIX_OK) return 1;
    unsigned n = 0;
    const char *message = nix_err_msg(NULL, s->ctx, &n);
    agentic_ai_lab_nix_capture(message, n, &s->error);
    return 0;
}

static agentic_ai_lab_nix_session *agentic_ai_lab_nix_create(void)
{
    agentic_ai_lab_nix_session *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    s->ctx = nix_c_context_create();
    if (!s->ctx) { free(s); return NULL; }
    if (!agentic_ai_lab_nix_profile_start()) {
        s->error = strdup("loaded Nix GC lacks required qualification counters");
        return s;
    }
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    nix_libexpr_init(s->ctx);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_INIT, start);
    if (!agentic_ai_lab_nix_status(s)) return s;
    start = agentic_ai_lab_nix_now();
    s->store = nix_store_open(s->ctx, "auto", NULL);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_STORE, start);
    if (!agentic_ai_lab_nix_status(s)) return s;
    start = agentic_ai_lab_nix_now();
    s->state = nix_state_create(s->ctx, NULL, s->store);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_STATE, start);
    if (!agentic_ai_lab_nix_status(s)) return s;
    return s;
}

static agentic_ai_lab_nix_session *agentic_ai_lab_nix_open(const char *expression, const char *directory)
{
    agentic_ai_lab_nix_session *s = agentic_ai_lab_nix_create();
    if (!s || s->error) return s;
    s->function = nix_alloc_value(s->ctx, s->state);
    if (!agentic_ai_lab_nix_status(s)) return s;
    nix_expr_eval_from_string(s->ctx, s->state, expression, directory, s->function);
    agentic_ai_lab_nix_status(s);
    return s;
}

/* Parsing, strict locking and output selection all use libflake-c. No getFlake
 * expression, lock-file parser or CLI argument emulation lives in this bridge. */
static nix_flake_reference *agentic_ai_lab_nix_reference(agentic_ai_lab_nix_session *s, const char *text,
                                            const char *directory)
{
    nix_flake_reference_parse_flags *flags =
        nix_flake_reference_parse_flags_new(s->ctx, s->flakes);
    nix_flake_reference *reference = NULL;
    char *fragment = NULL;
    if (!agentic_ai_lab_nix_status(s)) return NULL;
    nix_flake_reference_parse_flags_set_base_directory(s->ctx, flags, directory, strlen(directory));
    if (agentic_ai_lab_nix_status(s)) {
        nix_flake_reference_and_fragment_from_string(s->ctx, s->fetchers, s->flakes,
            flags, text, strlen(text), &reference, agentic_ai_lab_nix_capture, &fragment);
        if (agentic_ai_lab_nix_status(s) && fragment && *fragment) {
            nix_set_err_msg(s->ctx, NIX_ERR_UNKNOWN, "flake fragment must use the separate attribute argument");
            agentic_ai_lab_nix_status(s);
        }
        free(fragment);
    }
    nix_flake_reference_parse_flags_free(flags);
    if (s->error) {
        if (reference) nix_flake_reference_free(reference);
        return NULL;
    }
    return reference;
}

static agentic_ai_lab_nix_session *agentic_ai_lab_nix_flake_create(void)
{
    agentic_ai_lab_nix_session *s = agentic_ai_lab_nix_create();
    if (!s || s->error) return s;
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    nix_setting_set(s->ctx, "experimental-features", "nix-command flakes");
    if (!agentic_ai_lab_nix_status(s)) return s;
    s->fetchers = nix_fetchers_settings_new(s->ctx);
    if (!agentic_ai_lab_nix_status(s)) return s;
    s->flakes = nix_flake_settings_new(s->ctx);
    if (!agentic_ai_lab_nix_status(s)) return s;
    s->lock_flags = nix_flake_lock_flags_new(s->ctx, s->flakes);
    if (!agentic_ai_lab_nix_status(s)) return s;
    nix_flake_lock_flags_set_mode_check(s->ctx, s->lock_flags);
    if (!agentic_ai_lab_nix_status(s)) return s;
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_SETTINGS, start);
    return s;
}

static agentic_ai_lab_nix_session *agentic_ai_lab_nix_flake_prepare(const char *reference, const char *directory)
{
    agentic_ai_lab_nix_session *s = agentic_ai_lab_nix_flake_create();
    if (s && !s->error) s->reference = agentic_ai_lab_nix_reference(s, reference, directory);
    return s;
}

static int agentic_ai_lab_nix_flake_override(agentic_ai_lab_nix_session *s, const char *name,
                                  const char *reference, const char *directory)
{
    if (s->error) return 0;
    nix_flake_reference *input = agentic_ai_lab_nix_reference(s, reference, directory);
    if (!input) return 0;
    /* libflake-c explicitly preserves mode_check when adding an override. */
    nix_flake_lock_flags_add_input_override(s->ctx, s->lock_flags, name, input);
    nix_flake_reference_free(input);
    return agentic_ai_lab_nix_status(s);
}

static int agentic_ai_lab_nix_flake_select(agentic_ai_lab_nix_session *s, const char *attribute)
{
    if (s->error || !s->reference) return 0;
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    nix_locked_flake *locked = nix_flake_lock(s->ctx, s->fetchers, s->flakes,
        s->state, s->lock_flags, s->reference);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_LOCK, start);
    if (!agentic_ai_lab_nix_status(s)) return 0;
    start = agentic_ai_lab_nix_now();
    nix_value *value = nix_locked_flake_get_output_attrs(s->ctx, s->flakes, s->state, locked);
    nix_locked_flake_free(locked);
    if (!agentic_ai_lab_nix_status(s)) return 0;
    char *path = strdup(attribute), *cursor = path, *name;
    if (!path) { nix_value_decref(NULL, value); return 0; }
    while ((name = strsep(&cursor, "."))) {
        nix_value *next = nix_get_attr_byname(s->ctx, value, s->state, name);
        nix_value_decref(NULL, value);
        value = next;
        if (!agentic_ai_lab_nix_status(s)) { free(path); return 0; }
    }
    free(path);
    if (s->function) nix_value_decref(NULL, s->function);
    s->function = value;
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_OUTPUTS, start);
    return 1;
}

/* Re-lock on every independent product query, while retaining Store/EvalState.
 * A selected output thunk cannot authenticate a later filesystem generation. */
static int agentic_ai_lab_nix_flake_reset(agentic_ai_lab_nix_session *s, const char *reference, const char *directory)
{
    if (s->reference) nix_flake_reference_free(s->reference);
    if (s->lock_flags) nix_flake_lock_flags_free(s->lock_flags);
    free(s->error); s->error = NULL;
    nix_clear_err(s->ctx);
    s->reference = NULL;
    s->lock_flags = nix_flake_lock_flags_new(s->ctx, s->flakes);
    if (!agentic_ai_lab_nix_status(s)) return 0;
    nix_flake_lock_flags_set_mode_check(s->ctx, s->lock_flags);
    if (!agentic_ai_lab_nix_status(s)) return 0;
    s->reference = agentic_ai_lab_nix_reference(s, reference, directory);
    return s->reference != NULL;
}

static int agentic_ai_lab_nix_derivation_function(agentic_ai_lab_nix_session *s, int applied, const char *directory)
{
    nix_value *adapter = nix_alloc_value(s->ctx, s->state);
    nix_value *function = nix_alloc_value(s->ctx, s->state);
    int ok = agentic_ai_lab_nix_status(s);
    if (ok) {
        nix_expr_eval_from_string(s->ctx, s->state,
            applied ? "value: input: (value (builtins.fromJSON input)).drvPath"
                    : "value: input: value.drvPath", directory, adapter);
        ok = agentic_ai_lab_nix_status(s);
    }
    if (ok) {
        nix_value_call(s->ctx, s->state, adapter, s->function, function);
        ok = agentic_ai_lab_nix_status(s);
    }
    if (ok) {
        nix_value_decref(NULL, s->function);
        s->function = function;
    } else if (function) nix_value_decref(NULL, function);
    if (adapter) nix_value_decref(NULL, adapter);
    return ok;
}

static int agentic_ai_lab_nix_pure(agentic_ai_lab_nix_session *s)
{
    /* pure-eval belongs to EvalSettings, not the global settings registry.
     * Inspect the effective state, rather than accepting an environment label. */
    nix_value *value = nix_alloc_value(s->ctx, s->state);
    int ok = agentic_ai_lab_nix_status(s);
    if (ok) {
        nix_expr_eval_from_string(s->ctx, s->state,
            "!(builtins ? currentSystem) && !(builtins ? currentTime)", "/", value);
        ok = agentic_ai_lab_nix_status(s);
    }
    if (ok) {
        ok = nix_get_bool(s->ctx, value);
        ok = agentic_ai_lab_nix_status(s) && ok;
    }
    if (value) nix_value_decref(NULL, value);
    return ok;
}

/* One explicit native application; diagnostic attribute reads share its thunks.
 * This does not cache an admission verdict or a cross-session result. */
static int agentic_ai_lab_nix_apply(agentic_ai_lab_nix_session *s, const char *input)
{
    if (s->error || !s->function) return 0;
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    if (s->pending) nix_value_decref(NULL, s->pending);
    s->pending = nix_alloc_value(s->ctx, s->state);
    nix_value *argument = nix_alloc_value(s->ctx, s->state);
    int ok = agentic_ai_lab_nix_status(s);
    if (ok) { nix_init_string(s->ctx, argument, input); ok = agentic_ai_lab_nix_status(s); }
    if (ok) {
        ++s->calls;
        nix_value_call(s->ctx, s->state, s->function, argument, s->pending);
        ok = agentic_ai_lab_nix_status(s);
    }
    if (argument) nix_value_decref(NULL, argument);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_APPLY, start);
    return ok;
}
static int agentic_ai_lab_nix_copy_result(agentic_ai_lab_nix_session *s, nix_value *result)
{
    nix_get_string(s->ctx, result, agentic_ai_lab_nix_capture, &s->output);
    return agentic_ai_lab_nix_status(s) && s->output;
}
static int agentic_ai_lab_nix_query(agentic_ai_lab_nix_session *s, const char *input)
{
    if (!agentic_ai_lab_nix_apply(s, input)) return 0;
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    int ok = agentic_ai_lab_nix_copy_result(s, s->pending);
    nix_value_decref(NULL, s->pending);
    s->pending = NULL;
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_RESULT, start);
    return ok;
}
static int agentic_ai_lab_nix_result(agentic_ai_lab_nix_session *s, const char *attribute)
{
    if (s->error || !s->pending) return 0;
    agentic_ai_lab_nix_clock start = agentic_ai_lab_nix_now();
    nix_value *value = nix_get_attr_byname(s->ctx, s->pending, s->state, attribute);
    int ok = agentic_ai_lab_nix_status(s);
    if (ok) ok = agentic_ai_lab_nix_copy_result(s, value);
    if (value) nix_value_decref(NULL, value);
    agentic_ai_lab_nix_elapsed(s, AGENTIC_AI_LAB_RESULT, start);
    return ok;
}

static void agentic_ai_lab_nix_close(agentic_ai_lab_nix_session *s)
{
    if (!s) return;
    if (s->pending) nix_value_decref(NULL, s->pending);
    if (s->function) nix_value_decref(NULL, s->function);
    if (s->reference) nix_flake_reference_free(s->reference);
    if (s->lock_flags) nix_flake_lock_flags_free(s->lock_flags);
    if (s->flakes) nix_flake_settings_free(s->flakes);
    if (s->fetchers) nix_fetchers_settings_free(s->fetchers);
    if (s->state) nix_state_free(s->state);
    if (s->store) nix_store_free(s->store);
    nix_c_context_free(s->ctx);
    free(s->output);
    free(s->error);
    free(s);
}
