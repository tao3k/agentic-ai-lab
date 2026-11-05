;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: Gerbil FFI shim for nono's C ABI.
;;; Boundary: this file owns dlopen/dlsym and safe symbol probes only.

(import (only-in :std/ffi C-declare def-C-lambda))

(export nono_ffi_open
        nono_ffi_close
        nono_ffi_is_loaded
        nono_ffi_last_error
        nono_ffi_sandbox_is_supported
        nono_ffi_support_is_supported
        nono_ffi_support_platform
        nono_ffi_support_details
        nono_ffi_capability_roundtrip
        nono_ffi_apply_null)

(C-declare #<<END-C
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include "nono.h"

typedef struct NonoCapabilitySet *(*ffi_nono_capability_set_new_fn)(void);
typedef void (*ffi_nono_capability_set_free_fn)(struct NonoCapabilitySet *);
typedef enum NonoErrorCode (*ffi_nono_capability_set_set_network_mode_fn)(
    struct NonoCapabilitySet *, uint32_t);
typedef enum NonoErrorCode (*ffi_nono_sandbox_apply_fn)(
    const struct NonoCapabilitySet *);
typedef bool (*ffi_nono_sandbox_is_supported_fn)(void);
typedef struct NonoSupportInfo (*ffi_nono_sandbox_support_info_fn)(void);
typedef void (*ffi_nono_string_free_fn)(char *);

static void *ffi_nono_handle = NULL;
static char ffi_nono_error[2048] = "";
static char ffi_nono_platform[256] = "";
static char ffi_nono_details[2048] = "";

static ffi_nono_capability_set_new_fn ffi_nono_capability_set_new = NULL;
static ffi_nono_capability_set_free_fn ffi_nono_capability_set_free = NULL;
static ffi_nono_capability_set_set_network_mode_fn
    ffi_nono_capability_set_set_network_mode = NULL;
static ffi_nono_sandbox_apply_fn ffi_nono_sandbox_apply = NULL;
static ffi_nono_sandbox_is_supported_fn ffi_nono_sandbox_is_supported_symbol = NULL;
static ffi_nono_sandbox_support_info_fn ffi_nono_sandbox_support_info = NULL;
static ffi_nono_string_free_fn ffi_nono_string_free = NULL;

static void ffi_nono_set_error(const char *message) {
  if (message == NULL) {
    ffi_nono_error[0] = '\0';
  } else {
    snprintf(ffi_nono_error, sizeof(ffi_nono_error), "%s", message);
  }
}

static void ffi_nono_clear_symbols(void) {
  ffi_nono_capability_set_new = NULL;
  ffi_nono_capability_set_free = NULL;
  ffi_nono_capability_set_set_network_mode = NULL;
  ffi_nono_sandbox_apply = NULL;
  ffi_nono_sandbox_is_supported_symbol = NULL;
  ffi_nono_sandbox_support_info = NULL;
  ffi_nono_string_free = NULL;
}

static void *ffi_nono_resolve_symbol(const char *name) {
  dlerror();
  void *symbol = dlsym(ffi_nono_handle, name);
  const char *error = dlerror();
  if (error != NULL) {
    ffi_nono_set_error(error);
    return NULL;
  }
  if (symbol == NULL) {
    snprintf(ffi_nono_error, sizeof(ffi_nono_error),
             "missing runtime nono symbol: %s", name);
  }
  return symbol;
}

static int ffi_nono_resolve_symbols(void) {
  ffi_nono_capability_set_new =
      (ffi_nono_capability_set_new_fn)
      ffi_nono_resolve_symbol("nono_capability_set_new");
  if (ffi_nono_capability_set_new == NULL) return -1;

  ffi_nono_capability_set_free =
      (ffi_nono_capability_set_free_fn)
      ffi_nono_resolve_symbol("nono_capability_set_free");
  if (ffi_nono_capability_set_free == NULL) return -1;

  ffi_nono_capability_set_set_network_mode =
      (ffi_nono_capability_set_set_network_mode_fn)
      ffi_nono_resolve_symbol("nono_capability_set_set_network_mode");
  if (ffi_nono_capability_set_set_network_mode == NULL) return -1;

  ffi_nono_sandbox_apply =
      (ffi_nono_sandbox_apply_fn)
      ffi_nono_resolve_symbol("nono_sandbox_apply");
  if (ffi_nono_sandbox_apply == NULL) return -1;

  ffi_nono_sandbox_is_supported_symbol =
      (ffi_nono_sandbox_is_supported_fn)
      ffi_nono_resolve_symbol("nono_sandbox_is_supported");
  if (ffi_nono_sandbox_is_supported_symbol == NULL) return -1;

  ffi_nono_sandbox_support_info =
      (ffi_nono_sandbox_support_info_fn)
      ffi_nono_resolve_symbol("nono_sandbox_support_info");
  if (ffi_nono_sandbox_support_info == NULL) return -1;

  ffi_nono_string_free =
      (ffi_nono_string_free_fn)
      ffi_nono_resolve_symbol("nono_string_free");
  if (ffi_nono_string_free == NULL) return -1;

  ffi_nono_set_error(NULL);
  return 0;
}

static int ffi_nono_open(char *library_path) {
  if (library_path == NULL || library_path[0] == '\0') {
    ffi_nono_set_error("runtime nono library path is empty");
    return -1;
  }
  if (ffi_nono_handle != NULL) {
    dlclose(ffi_nono_handle);
    ffi_nono_handle = NULL;
    ffi_nono_clear_symbols();
  }
  dlerror();
  ffi_nono_handle = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
  if (ffi_nono_handle == NULL) {
    const char *error = dlerror();
    ffi_nono_set_error(error == NULL ? "dlopen failed" : error);
    return -1;
  }
  if (ffi_nono_resolve_symbols() != 0) {
    dlclose(ffi_nono_handle);
    ffi_nono_handle = NULL;
    ffi_nono_clear_symbols();
    return -1;
  }
  return 0;
}

static int ffi_nono_close(void) {
  int rc = 0;
  if (ffi_nono_handle != NULL) {
    rc = dlclose(ffi_nono_handle);
  }
  ffi_nono_handle = NULL;
  ffi_nono_clear_symbols();
  return rc;
}

static int ffi_nono_is_loaded(void) {
  return ffi_nono_handle != NULL ? 1 : 0;
}

static char *ffi_nono_last_error(void) {
  return ffi_nono_error;
}

static int ffi_nono_sandbox_is_supported(void) {
  if (ffi_nono_sandbox_is_supported_symbol == NULL) {
    ffi_nono_set_error("nono_sandbox_is_supported is not loaded");
    return -1;
  }
  return ffi_nono_sandbox_is_supported_symbol() ? 1 : 0;
}

static struct NonoSupportInfo ffi_nono_support_info(void) {
  struct NonoSupportInfo empty;
  empty.is_supported = false;
  empty.platform = NULL;
  empty.details = NULL;
  if (ffi_nono_sandbox_support_info == NULL) {
    ffi_nono_set_error("nono_sandbox_support_info is not loaded");
    return empty;
  }
  return ffi_nono_sandbox_support_info();
}

static void ffi_nono_copy_support_info(void) {
  struct NonoSupportInfo info = ffi_nono_support_info();
  snprintf(ffi_nono_platform, sizeof(ffi_nono_platform), "%s",
           info.platform == NULL ? "" : info.platform);
  snprintf(ffi_nono_details, sizeof(ffi_nono_details), "%s",
           info.details == NULL ? "" : info.details);
  if (ffi_nono_string_free != NULL) {
    if (info.platform != NULL) ffi_nono_string_free(info.platform);
    if (info.details != NULL) ffi_nono_string_free(info.details);
  }
}

static char *ffi_nono_support_platform(void) {
  ffi_nono_copy_support_info();
  return ffi_nono_platform;
}

static char *ffi_nono_support_details(void) {
  ffi_nono_copy_support_info();
  return ffi_nono_details;
}

static int ffi_nono_support_is_supported(void) {
  struct NonoSupportInfo info = ffi_nono_support_info();
  int result = info.is_supported ? 1 : 0;
  if (ffi_nono_string_free != NULL) {
    if (info.platform != NULL) ffi_nono_string_free(info.platform);
    if (info.details != NULL) ffi_nono_string_free(info.details);
  }
  return result;
}

static int ffi_nono_capability_roundtrip(void) {
  if (ffi_nono_capability_set_new == NULL ||
      ffi_nono_capability_set_free == NULL ||
      ffi_nono_capability_set_set_network_mode == NULL) {
    ffi_nono_set_error("capability-set runtime symbols are not loaded");
    return -1000;
  }

  struct NonoCapabilitySet *caps = ffi_nono_capability_set_new();
  if (caps == NULL) {
    ffi_nono_set_error("nono_capability_set_new returned NULL");
    return -1001;
  }

  enum NonoErrorCode rc =
      ffi_nono_capability_set_set_network_mode(caps, NONO_NETWORK_MODE_BLOCKED);
  ffi_nono_capability_set_free(caps);
  return (int)rc;
}

static int ffi_nono_apply_null(void) {
  if (ffi_nono_sandbox_apply == NULL) {
    ffi_nono_set_error("nono_sandbox_apply is not loaded");
    return -1000;
  }
  return (int)ffi_nono_sandbox_apply(NULL);
}
END-C
)

(def-C-lambda nono_ffi_open (char-string) int
  "ffi_nono_open")
(def-C-lambda nono_ffi_close () int
  "ffi_nono_close")
(def-C-lambda nono_ffi_is_loaded () int
  "ffi_nono_is_loaded")
(def-C-lambda nono_ffi_last_error () char-string
  "ffi_nono_last_error")
(def-C-lambda nono_ffi_sandbox_is_supported () int
  "ffi_nono_sandbox_is_supported")
(def-C-lambda nono_ffi_support_is_supported () int
  "ffi_nono_support_is_supported")
(def-C-lambda nono_ffi_support_platform () char-string
  "ffi_nono_support_platform")
(def-C-lambda nono_ffi_support_details () char-string
  "ffi_nono_support_details")
(def-C-lambda nono_ffi_capability_roundtrip () int
  "ffi_nono_capability_roundtrip")
(def-C-lambda nono_ffi_apply_null () int
  "ffi_nono_apply_null")
