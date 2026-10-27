;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; SDK Harness invocation with genuine module preparation progress only.
(import (only-in :gerbil/expander current-expander-module-import
                 current-expander-module-eval current-expander-eval
                 current-expander-context current-expander-phi
                 module-context? expander-context-id)
        (only-in :std/sync/threads thread-group->thread-list*)
        (rename-in (only-in :gerbil/tools/gxtest main) (main native-test-main)))
(export main)

(def (main . arguments)
  (def native-import (current-expander-module-import))
  (def native-eval (current-expander-module-eval))
  (def native-expression-eval (current-expander-eval))
  (def imported (make-hash-table-eq))
  (def evaluated (make-hash-table-eq))
  (def bodies (make-hash-table-eq))
  (def body-count 0)
  (def (completed phase seen context)
    ;; Count each exact SDK instance once per phase. Cached/replayed demands
    ;; cannot renew liveness, and these invocation-local tables stay bounded.
    (when (and (module-context? context) (not (hash-key? seen context))
               (< (hash-length seen) 4096))
      (hash-put! seen context #t)
      (displayln "NATIVE-MODULE-OK phase=" phase " module=" (expander-context-id context))
      (force-output)))
  (parameterize
    ((current-expander-module-import
       (lambda (path reload?)
         (let (context (native-import path reload?))
           (completed 'import imported context)
           context)))
     (current-expander-module-eval
       (lambda (context)
         (begin0 (native-eval context)
           (completed 'evaluation evaluated context))))
     (current-expander-eval
       (lambda (expression)
         (def context (current-expander-context))
         (def phi (current-expander-phi))
         (begin0 (native-expression-eval expression)
           ;; Recursive dependency evaluation forces module bodies directly,
           ;; bypassing the outer module-eval parameter. Observe completion at
           ;; this native body boundary, once per exact context and phase.
           (when (and (module-context? context) (< body-count 4096)
                      (not (memv phi (hash-ref bodies context '()))))
             (hash-put! bodies context (cons phi (hash-ref bodies context '())))
             (set! body-count (+ body-count 1))
             (displayln "NATIVE-MODULE-OK phase=body phi=" phi
                        " module=" (expander-context-id context))
             (force-output))))))
    ;; The SDK still discovers, prepares and runs every original Suite/Case.
    ;; Propagate its failure while leaving successful VM shutdown natural.
    (let (status (apply native-test-main arguments))
      (unless (zero? status) (error "native SDK Harness failed" status))
      (when (getenv "AGENTIC_AI_LAB_HARNESS_DIAGNOSTICS" #f)
        ;; Inspect live resources only after the SDK returns. This neither
        ;; terminates a worker nor converts a hung shutdown into a passing exit.
        (for-each
          (lambda (thread)
            (displayln "NATIVE-HARNESS-THREAD name=" (thread-name thread)
                       " current?=" (eq? thread (current-thread))
                       " state=" (thread-state thread)))
          (thread-group->thread-list* (thread-thread-group (current-thread))))
        (force-output)))))
