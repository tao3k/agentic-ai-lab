;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Diagnostic-only POSIX counters. Importing starts no process or sampler.
(import :std/ffi)
(export process-accounting-sample)
(C-include "<sys/resource.h>")
(def-C-lambda (sample! (out : scheme-object)) => int
  #<<C
struct rusage r;
int status = getrusage(RUSAGE_SELF, &r);
if (!status) {
  ___F64VECTORSET(___arg1, ___FIX(0), (double) r.ru_nvcsw);
  ___F64VECTORSET(___arg1, ___FIX(1), (double) r.ru_nivcsw);
  ___F64VECTORSET(___arg1, ___FIX(2), (double) r.ru_minflt);
  ___F64VECTORSET(___arg1, ___FIX(3), (double) r.ru_majflt);
  ___F64VECTORSET(___arg1, ___FIX(4), (double) r.ru_inblock);
  ___F64VECTORSET(___arg1, ___FIX(5), (double) r.ru_oublock);
}
___result = status;
C
)
(def (process-accounting-sample)
  (def out (make-f64vector 6 0.))
  (unless (zero? (sample! out)) (error "getrusage failed"))
  out)
