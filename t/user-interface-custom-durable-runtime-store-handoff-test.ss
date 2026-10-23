;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable runtime store handoff scenario.
;;; Invariant: user config projects negotiation and handoff data only; Marlin
;;; owns the runtime store implementation.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/durable-runtime-store-handoff"
                 agentic-ai-lab-custom-my-module-durable-runtime-store-handoff-case))

(export user-interface-custom-durable-runtime-store-handoff-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-durable-runtime-store-handoff-test
  (test-suite "agentic-ai-lab custom durable runtime store handoff case"
    (yuanxu-test-case "projects backend negotiation and Marlin handoff"
      (let* ((negotiation-row
              (car agentic-ai-lab-custom-my-module-durable-runtime-store-handoff-case))
             (handoff-row
              (cadr agentic-ai-lab-custom-my-module-durable-runtime-store-handoff-case))
             (manifest (test-ref handoff-row 'runtime-command-manifest)))
        (check-equal? (test-ref negotiation-row 'kind)
                      'agentic-ai-lab.durable.runtime-store-negotiation-receipt)
        (check-equal? (test-ref negotiation-row 'store-id)
                      'runtime-store/custom-project)
        (check-equal? (test-ref negotiation-row 'backend-id)
                      'runtime-backend/marlin-store)
        (check-equal? (test-ref negotiation-row 'valid?) #t)
        (check-equal? (test-ref negotiation-row 'handoff-ready?) #t)
        (check-equal? (test-ref negotiation-row 'runtime-executed) #f)
        (check-equal? (test-ref handoff-row 'kind)
                      'agentic-ai-lab.durable.runtime-store.marlin-handoff)
        (check-equal? (test-ref handoff-row 'handoff-ready?) #t)
        (check-equal? (test-ref handoff-row 'operation)
                      'durable-runtime-store-negotiate)
        (check-equal? (test-ref manifest 'executable)
                      "marlin-runtime-store")
        (check-equal? (test-ref manifest 'argv)
                      '("marlin-runtime-store"
                        "durable-runtime-store"
                        "negotiate"))
        (check-equal? (test-ref handoff-row 'runtime-executed) #f)))))
