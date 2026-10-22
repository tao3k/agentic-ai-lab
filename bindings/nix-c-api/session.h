/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
 * Private, serial qualification bridge. Never installed into Yuanxu.
 */
#include <nix_api_expr.h>
#include <nix_api_value.h>
#include <nix_api_flake.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum { PF_INIT, PF_STORE, PF_STATE, PF_SETTINGS, PF_LOCK, PF_OUTPUTS,
       PF_APPLY, PF_RESULT, PF_PHASES };
typedef struct { double wall, cpu; } pf_nix_clock;
static pf_nix_clock pf_nix_now(void)
{
    struct timespec wall, cpu;
    clock_gettime(CLOCK_MONOTONIC, &wall);
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpu);
    return (pf_nix_clock){wall.tv_sec + wall.tv_nsec * 1e-9,
                          cpu.tv_sec + cpu.tv_nsec * 1e-9};
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
    double wall[PF_PHASES], cpu[PF_PHASES];
    unsigned phase_calls[PF_PHASES];
} pf_nix_session;

static void pf_nix_elapsed(pf_nix_session *s, int phase, pf_nix_clock start)
{
    pf_nix_clock end = pf_nix_now();
    s->wall[phase] += end.wall - start.wall;
    s->cpu[phase] += end.cpu - start.cpu;
    ++s->phase_calls[phase];
}
static double pf_nix_seconds(pf_nix_session *s, int phase, int cpu)
{
    if (phase < 0 || phase >= PF_PHASES) return -1;
    return cpu ? s->cpu[phase] : s->wall[phase];
}
static unsigned pf_nix_phase_calls(pf_nix_session *s, int phase)
{
    return phase >= 0 && phase < PF_PHASES ? s->phase_calls[phase] : 0;
}

static void pf_nix_capture(const char *bytes, unsigned n, void *data)
{
    char **destination = data;
    free(*destination);
    *destination = malloc((size_t)n + 1);
    if (*destination) {
        memcpy(*destination, bytes, n);
        (*destination)[n] = 0;
    }
}

static int pf_nix_status(pf_nix_session *s)
{
    if (nix_err_code(s->ctx) == NIX_OK) return 1;
    unsigned n = 0;
    const char *message = nix_err_msg(NULL, s->ctx, &n);
    pf_nix_capture(message, n, &s->error);
    return 0;
}

static pf_nix_session *pf_nix_create(void)
{
    pf_nix_session *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    s->ctx = nix_c_context_create();
    if (!s->ctx) { free(s); return NULL; }
    pf_nix_clock start = pf_nix_now();
    nix_libexpr_init(s->ctx);
    pf_nix_elapsed(s, PF_INIT, start);
    if (!pf_nix_status(s)) return s;
    start = pf_nix_now();
    s->store = nix_store_open(s->ctx, "auto", NULL);
    pf_nix_elapsed(s, PF_STORE, start);
    if (!pf_nix_status(s)) return s;
    start = pf_nix_now();
    s->state = nix_state_create(s->ctx, NULL, s->store);
    pf_nix_elapsed(s, PF_STATE, start);
    if (!pf_nix_status(s)) return s;
    return s;
}

static pf_nix_session *pf_nix_open(const char *expression, const char *directory)
{
    pf_nix_session *s = pf_nix_create();
    if (!s || s->error) return s;
    s->function = nix_alloc_value(s->ctx, s->state);
    if (!pf_nix_status(s)) return s;
    nix_expr_eval_from_string(s->ctx, s->state, expression, directory, s->function);
    pf_nix_status(s);
    return s;
}

/* Parsing, strict locking and output selection all use libflake-c. No getFlake
 * expression, lock-file parser or CLI argument emulation lives in this bridge. */
static nix_flake_reference *pf_nix_reference(pf_nix_session *s, const char *text,
                                            const char *directory)
{
    nix_flake_reference_parse_flags *flags =
        nix_flake_reference_parse_flags_new(s->ctx, s->flakes);
    nix_flake_reference *reference = NULL;
    char *fragment = NULL;
    if (!pf_nix_status(s)) return NULL;
    nix_flake_reference_parse_flags_set_base_directory(s->ctx, flags, directory, strlen(directory));
    if (pf_nix_status(s)) {
        nix_flake_reference_and_fragment_from_string(s->ctx, s->fetchers, s->flakes,
            flags, text, strlen(text), &reference, pf_nix_capture, &fragment);
        if (pf_nix_status(s) && fragment && *fragment) {
            nix_set_err_msg(s->ctx, NIX_ERR_UNKNOWN, "flake fragment must use the separate attribute argument");
            pf_nix_status(s);
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

static pf_nix_session *pf_nix_flake_prepare(const char *reference, const char *directory)
{
    pf_nix_session *s = pf_nix_create();
    if (!s || s->error) return s;
    pf_nix_clock start = pf_nix_now();
    nix_setting_set(s->ctx, "experimental-features", "nix-command flakes");
    if (!pf_nix_status(s)) return s;
    s->fetchers = nix_fetchers_settings_new(s->ctx);
    if (!pf_nix_status(s)) return s;
    s->flakes = nix_flake_settings_new(s->ctx);
    if (!pf_nix_status(s)) return s;
    s->lock_flags = nix_flake_lock_flags_new(s->ctx, s->flakes);
    if (!pf_nix_status(s)) return s;
    nix_flake_lock_flags_set_mode_check(s->ctx, s->lock_flags);
    if (!pf_nix_status(s)) return s;
    s->reference = pf_nix_reference(s, reference, directory);
    pf_nix_elapsed(s, PF_SETTINGS, start);
    return s;
}

static int pf_nix_flake_override(pf_nix_session *s, const char *name,
                                  const char *reference, const char *directory)
{
    if (s->error) return 0;
    nix_flake_reference *input = pf_nix_reference(s, reference, directory);
    if (!input) return 0;
    /* libflake-c explicitly preserves mode_check when adding an override. */
    nix_flake_lock_flags_add_input_override(s->ctx, s->lock_flags, name, input);
    nix_flake_reference_free(input);
    return pf_nix_status(s);
}

static int pf_nix_flake_select(pf_nix_session *s, const char *attribute)
{
    if (s->error || !s->reference) return 0;
    pf_nix_clock start = pf_nix_now();
    nix_locked_flake *locked = nix_flake_lock(s->ctx, s->fetchers, s->flakes,
        s->state, s->lock_flags, s->reference);
    pf_nix_elapsed(s, PF_LOCK, start);
    if (!pf_nix_status(s)) return 0;
    start = pf_nix_now();
    nix_value *value = nix_locked_flake_get_output_attrs(s->ctx, s->flakes, s->state, locked);
    nix_locked_flake_free(locked);
    if (!pf_nix_status(s)) return 0;
    char *path = strdup(attribute), *cursor = path, *name;
    if (!path) { nix_value_decref(NULL, value); return 0; }
    while ((name = strsep(&cursor, "."))) {
        nix_value *next = nix_get_attr_byname(s->ctx, value, s->state, name);
        nix_value_decref(NULL, value);
        value = next;
        if (!pf_nix_status(s)) { free(path); return 0; }
    }
    free(path);
    s->function = value;
    pf_nix_elapsed(s, PF_OUTPUTS, start);
    return 1;
}

/* One explicit native application; diagnostic attribute reads share its thunks.
 * This does not cache an admission verdict or a cross-session result. */
static int pf_nix_apply(pf_nix_session *s, const char *input)
{
    if (s->error || !s->function) return 0;
    pf_nix_clock start = pf_nix_now();
    if (s->pending) nix_value_decref(NULL, s->pending);
    s->pending = nix_alloc_value(s->ctx, s->state);
    nix_value *argument = nix_alloc_value(s->ctx, s->state);
    int ok = pf_nix_status(s);
    if (ok) { nix_init_string(s->ctx, argument, input); ok = pf_nix_status(s); }
    if (ok) {
        ++s->calls;
        nix_value_call(s->ctx, s->state, s->function, argument, s->pending);
        ok = pf_nix_status(s);
    }
    if (argument) nix_value_decref(NULL, argument);
    pf_nix_elapsed(s, PF_APPLY, start);
    return ok;
}
static int pf_nix_copy_result(pf_nix_session *s, nix_value *result)
{
    nix_get_string(s->ctx, result, pf_nix_capture, &s->output);
    return pf_nix_status(s) && s->output;
}
static int pf_nix_query(pf_nix_session *s, const char *input)
{
    if (!pf_nix_apply(s, input)) return 0;
    pf_nix_clock start = pf_nix_now();
    int ok = pf_nix_copy_result(s, s->pending);
    nix_value_decref(NULL, s->pending);
    s->pending = NULL;
    pf_nix_elapsed(s, PF_RESULT, start);
    return ok;
}
static int pf_nix_result(pf_nix_session *s, const char *attribute)
{
    if (s->error || !s->pending) return 0;
    pf_nix_clock start = pf_nix_now();
    nix_value *value = nix_get_attr_byname(s->ctx, s->pending, s->state, attribute);
    int ok = pf_nix_status(s);
    if (ok) ok = pf_nix_copy_result(s, value);
    if (value) nix_value_decref(NULL, value);
    pf_nix_elapsed(s, PF_RESULT, start);
    return ok;
}

static void pf_nix_close(pf_nix_session *s)
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
