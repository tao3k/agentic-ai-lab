;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable operation bridge scenario.
;;; Invariant: user config bridges durable rows to operation receipts only;
;;; Marlin owns runtime store execution.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/durable-operation-bridge"
                 agentic-ai-lab-custom-my-module-durable-operation-bridge-case))

(export user-interface-custom-durable-operation-bridge-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-durable-operation-bridge-test
  (test-suite "agentic-ai-lab custom durable operation bridge case"
    (yuanxu-test-case "bridges downstream rows to runtime store operations"
      (let* ((negotiation-row
              (car agentic-ai-lab-custom-my-module-durable-operation-bridge-case))
             (operation-rows
              (cadr agentic-ai-lab-custom-my-module-durable-operation-bridge-case))
             (handoff-row
              (caddr agentic-ai-lab-custom-my-module-durable-operation-bridge-case)))
        (check-equal? (test-ref negotiation-row 'handoff-ready?) #t)
        (check-equal? (length operation-rows) 7)
        (check-equal? (map (lambda (row) (test-ref row 'operation-kind))
                           operation-rows)
                      '(append-fact
                        append-communication-event
                        claim-job-lease
                        append-fact
                        retain-artifact
                        retain-artifact
                        attach-sandbox-handle))
        (check-equal? (map (lambda (row) (test-ref row 'valid?))
                           operation-rows)
                      '(#t #t #t #t #t #t #t))
        (check-equal? (test-ref handoff-row 'handoff-ready?) #t)
        (check-equal? (test-ref handoff-row 'operation-count) 7)
        (check-equal? (test-ref handoff-row 'runtime-executed) #f)))))
