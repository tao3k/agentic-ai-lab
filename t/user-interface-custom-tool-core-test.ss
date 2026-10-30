;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface tool-core scenario.
;;; Invariant: user config declares tool specs and validation receipts only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/tool-core"
                 agentic-ai-lab-custom-my-module-tool-core-case))

(export user-interface-custom-tool-core-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-tool-core-test
  (test-suite "agentic-ai-lab custom user-interface tool-core case"
    (yuanxu-test-case "projects custom tool-core case without runtime execution"
      (let* ((selection-row
              (car agentic-ai-lab-custom-my-module-tool-core-case))
             (catalog-row
              (cadr agentic-ai-lab-custom-my-module-tool-core-case))
             (validation-row
              (caddr agentic-ai-lab-custom-my-module-tool-core-case)))
        (check-equal? (test-ref selection-row 'key)
                      '(session . tool-core))
        (check-equal? (test-ref catalog-row 'catalog-ref)
                      'tool-core/custom)
        (check-equal? (test-ref catalog-row 'tool-refs)
                      '(calculator))
        (check-equal? (test-ref validation-row 'valid?) #f)
        (check-equal? (test-ref validation-row 'resolved-tool-refs)
                      '(calculator))
        (check-equal?
         (test-ref (car (test-ref validation-row 'action-mismatch-grants))
                   'grant-id)
         'grant/calculator-delete)
        (check-equal?
         (test-ref (car (test-ref validation-row 'diagnostics)) 'code)
         'tool-grant-action-not-supported)
        (check-equal? (test-ref validation-row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref validation-row 'runtime-executed) #f)))))
