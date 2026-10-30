;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The only platform primitive; scheduling/admission remains Scheme.
prelude: :gerbil/core
(import (only-in :std/ffi C-declare def-C-lambda))
(export native-monotonic-seconds native-boot-identity)
(C-declare "#include <time.h>\nstatic double context_monotonic_seconds(void) { struct timespec t; if (clock_gettime(CLOCK_MONOTONIC, &t)) return -1.; return (double)t.tv_sec + (double)t.tv_nsec / 1000000000.; }")
(def-C-lambda os-monotonic-seconds () double "context_monotonic_seconds")
(def (native-monotonic-seconds)
  (let (value (os-monotonic-seconds))
    (when (< value 0) (error "CLOCK_MONOTONIC unavailable")) value))

(C-declare "#include <stdio.h>\n#include <string.h>\n#ifdef __APPLE__\n#include <sys/types.h>\n#include <sys/sysctl.h>\n#endif\nstatic char *context_boot_id(void) { static char id[128];\n#ifdef __APPLE__\nsize_t n=sizeof(id); if(sysctlbyname(\"kern.bootsessionuuid\",id,&n,NULL,0)) return NULL;\n#else\nFILE *f=fopen(\"/proc/sys/kernel/random/boot_id\",\"r\"); if(!f) return NULL; if(!fgets(id,sizeof(id),f)){fclose(f);return NULL;} fclose(f);\n#endif\nid[strcspn(id,\"\\r\\n\")]=0; return id; }")
(def-C-lambda os-boot-id () char-string "context_boot_id")
(def (native-boot-identity)
  (let (value (os-boot-id))
    (unless (and (string? value) (< 0 (string-length value) 128)) (error "Boot identity unavailable"))
    (string-copy value)))
