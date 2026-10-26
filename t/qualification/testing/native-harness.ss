;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; SDK Harness invocation with genuine module preparation progress only.
(import (only-in :gerbil/expander current-expander-module-import
                 current-expander-module-eval module-context? expander-context-id)
        (rename-in (only-in :gerbil/tools/gxtest main) (main native-test-main)))
(export main)

(def (main . arguments)
  (def native-import (current-expander-module-import))
  (def native-eval (current-expander-module-eval))
  (def imported (make-hash-table-eq))
  (def evaluated (make-hash-table-eq))
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
           (completed 'evaluation evaluated context)))))
    ;; The SDK still discovers, prepares and runs every original Suite/Case.
    ;; Propagate its failure while leaving successful VM shutdown natural.
    (let (status (apply native-test-main arguments))
      (unless (zero? status) (error "native SDK Harness failed" status)))))
