;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable runtime store operation scenario.
;;; Invariant: user config projects operation receipts and handoff data only;
;;; Marlin owns runtime store execution.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-operation
                 +agentic-ai-lab-durable-runtime-store-operation-specs+)
        (only-in "../user-interface/custom/my-module/cases/durable-runtime-store-operations"
                 agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case))

(export user-interface-custom-durable-runtime-store-operations-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-durable-runtime-store-operations-test
  (test-suite "agentic-ai-lab custom durable runtime store operation case"
    (yuanxu-test-case "projects operation receipts and Marlin handoff"
      (let* ((negotiation-row
              (car agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case))
             (operation-rows
              (cadr agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case))
             (handoff-row
              (caddr agentic-ai-lab-custom-my-module-durable-runtime-store-operations-case))
             (manifest (test-ref handoff-row 'runtime-command-manifest)))
        (check-equal? (test-ref negotiation-row 'handoff-ready?) #t)
        (check-equal? (length operation-rows)
                      (length +agentic-ai-lab-durable-runtime-store-operation-specs+))
        (check-equal? (map (lambda (row) (test-ref row 'operation-kind))
                           operation-rows)
                      (map car
                           +agentic-ai-lab-durable-runtime-store-operation-specs+))
        (check-equal? (map (lambda (row) (test-ref row 'valid?))
                           operation-rows)
                      '(#t #t #t #t #t #t #t #t))
        (check-equal? (map (lambda (row) (test-ref row 'runtime-executed))
                           operation-rows)
                      '(#f #f #f #f #f #f #f #f))
        (check-equal? (test-ref (car operation-rows) 'ledger-kind)
                      'fact-log)
        (check-equal? (test-ref handoff-row 'kind)
                      'agentic-ai-lab.durable.runtime-store.operation-handoff)
        (check-equal? (test-ref handoff-row 'handoff-ready?) #t)
        (check-equal? (test-ref handoff-row 'operation-count)
                      (length +agentic-ai-lab-durable-runtime-store-operation-specs+))
        (check-equal? (test-ref manifest 'argv)
                      '("marlin-runtime-store"
                        "durable-runtime-store"
                        "operations"))
        (check-equal? (test-ref handoff-row 'runtime-executed) #f)))))
