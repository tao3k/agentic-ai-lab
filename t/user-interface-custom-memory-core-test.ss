;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface memory-core scenario.
;;; Invariant: user config declares memory specs and validation receipts only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/memory-core"
                 agentic-ai-lab-custom-my-module-memory-core-case))

(export user-interface-custom-memory-core-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

(def user-interface-custom-memory-core-test
  (test-suite "agentic-ai-lab custom user-interface memory-core case"
    (yuanxu-test-case "projects custom memory-core case without runtime execution"
      (let* ((selection-row
              (car agentic-ai-lab-custom-my-module-memory-core-case))
             (catalog-row
              (cadr agentic-ai-lab-custom-my-module-memory-core-case))
             (validation-row
              (caddr agentic-ai-lab-custom-my-module-memory-core-case)))
        (check-equal? (test-ref selection-row 'key)
                      '(agentic . ai-agentic-context))
        (check-equal? (test-ref catalog-row 'catalog-ref)
                      'memory-core/custom)
        (check-equal? (test-ref catalog-row 'store-refs)
                      '(memory/project-notes))
        (check-equal? (test-ref validation-row 'valid?) #t)
        (check-equal? (test-ref validation-row 'resolved-store-refs)
                      '(memory/project-notes))
        (check-equal? (test-ref validation-row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref validation-row 'runtime-executed) #f)))))
