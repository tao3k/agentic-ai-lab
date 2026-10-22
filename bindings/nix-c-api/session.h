/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
 * Private, serial qualification bridge. Never installed into Yuanxu.
 */
#include <nix_api_expr.h>
#include <nix_api_value.h>
#include <nix_api_flake.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    nix_c_context *ctx;
    Store *store;
    EvalState *state;
    nix_value *function;
    nix_fetchers_settings *fetchers;
    nix_flake_settings *flakes;
    nix_flake_reference *reference;
    nix_flake_lock_flags *lock_flags;
    char *output;
    char *error;
    unsigned calls;
} pf_nix_session;

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
    nix_libexpr_init(s->ctx);
    if (!pf_nix_status(s)) return s;
    s->store = nix_store_open(s->ctx, "auto", NULL);
    if (!pf_nix_status(s)) return s;
    s->state = nix_state_create(s->ctx, NULL, s->store);
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
    nix_locked_flake *locked = nix_flake_lock(s->ctx, s->fetchers, s->flakes,
        s->state, s->lock_flags, s->reference);
    if (!pf_nix_status(s)) return 0;
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
    return 1;
}

static int pf_nix_query(pf_nix_session *s, const char *input)
{
    if (s->error || !s->function) return 0;
    nix_value *argument = nix_alloc_value(s->ctx, s->state);
    nix_value *result = nix_alloc_value(s->ctx, s->state);
    int ok = pf_nix_status(s);
    if (ok) { nix_init_string(s->ctx, argument, input); ok = pf_nix_status(s); }
    if (ok) {
        ++s->calls;
        nix_value_call(s->ctx, s->state, s->function, argument, result);
        ok = pf_nix_status(s);
    }
    if (ok) {
        nix_get_string(s->ctx, result, pf_nix_capture, &s->output);
        ok = pf_nix_status(s) && s->output;
    }
    if (result) nix_value_decref(NULL, result);
    if (argument) nix_value_decref(NULL, argument);
    return ok;
}

static void pf_nix_close(pf_nix_session *s)
{
    if (!s) return;
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
