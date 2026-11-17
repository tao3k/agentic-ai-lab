/* SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <string.h>

static atomic_bool terminal_cleanup;

int lab_arm_terminal_cleanup(void)
{
    atomic_store(&terminal_cleanup, true);
    return 1;
}

static int close_for_terminal_cleanup(void *handle)
{
    Dl_info caller;

    /* Keep Gambit's reference until normal process exit. Gambit still releases
       its module record, and ordinary dlclose calls keep their own lifetime. */
    if (atomic_load(&terminal_cleanup) &&
        dladdr(__builtin_return_address(0), &caller) &&
        caller.dli_sname &&
        strcmp(caller.dli_sname, "___cleanup_dyn_module") == 0)
        return 0;

    return dlclose(handle);
}

__attribute__((used, section("__DATA,__interpose")))
static const struct {
    const void *replacement;
    const void *original;
} close_interposition = {
    (const void *)close_for_terminal_cleanup, (const void *)dlclose
};
