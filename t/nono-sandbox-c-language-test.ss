;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: C language tests prove the nono-sandbox binding is compiler-visible.
;;; Invariant: the probe checks headers and signatures but never links or applies nono.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :std/misc/process run-process)
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/module-system/building/products current-build-module-roots)
        (only-in "../init.ss" tao3k/agentic-ai-lab.init.exports)
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-build
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor)

(export nono-sandbox-c-language-test)

;;; The compile probe is deliberately syntax-only: success means C can consume
;;; our adapter header, nono's generated header, constants, structs, and
;;; function declarations without needing a platform sandbox or runtime link step.
;; : (-> Unit String)
(def (run-nono-c-binding-compile-probe)
  (run-process (nono-c-binding-compile-probe-command)
               stderr-redirection: #t))

(def nono-sandbox-c-language-test
  (test-suite "nono-sandbox C language binding"
    (yuanxu-test-case "Nono contributes its own compiler and linker flags to init"
      (def spec
        (parameterize ((current-build-module-roots '(nono-sandbox)))
          (.get tao3k/agentic-ai-lab.init.exports std-make-spec)))
      (def target
        `(gxc: "modules/nono-sandbox/_nono"
               "-cc-options" ,(string-append "-I" (path-expand "modules/nono-sandbox/nono-c"))
               "-ld-options" ,(cond-expand (darwin "-Wl,-undefined,dynamic_lookup")
                                          (else "-ldl"))))
      (check-equal? (and (member target spec) #t) #t))
    (yuanxu-test-case "C compiler accepts Agentic AI Lab nono binding probe"
      (let* ((descriptor (make-nono-c-binding-descriptor))
             (contract (nono-c-binding-descriptor->contract descriptor)))
        (check-equal? (cdr (assoc 'adapter-header contract))
                      "agentic_ai_lab_nono_binding.h")
        (check-equal? (cdr (assoc 'adapter-include-ref contract))
                      "modules/nono-sandbox/nono-c/agentic_ai_lab_nono_binding.h")
        (check-equal? (cdr (assoc 'probe-ref contract))
                      "modules/nono-sandbox/nono-c/agentic_ai_lab_nono_binding_probe.c")
        (check-equal? (run-nono-c-binding-compile-probe) "")))))
