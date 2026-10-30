;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-materialization scenario.
;;; Invariant: materialization receipts are handoff state only; Scheme never
;;; waits on futures, opens sandboxes, or replays IO.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/session-materialization"
                 agentic-ai-lab-custom-my-module-session-materialization-case))

(export user-interface-custom-session-materialization-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Alist])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-materialization-test
  (test-suite "agentic-ai-lab custom user-interface session-materialization case"
    (yuanxu-test-case "projects custom materialization receipts without runtime work"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-materialization-case))
             (rows
              (module-config-rows
               agentic-ai-lab-custom-my-module-session-materialization-case))
             (pending (car rows))
             (failed (cadr rows)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (test-ref pending 'kind)
                      'agentic-ai-lab.session.materialization-receipt)
        (check-equal? (test-ref pending 'request-id)
                      'runtime/custom-build-request)
        (check-equal? (test-ref pending 'materialization-state) 'pending)
        (check-equal? (test-ref pending 'sandbox-handle-ref)
                      'sandbox/custom-build-handle)
        (check-equal? (test-ref failed 'request-id)
                      'runtime/custom-audit-request)
        (check-equal? (test-ref failed 'materialization-state) 'failed)
        (check-equal? (test-ref failed 'sandbox-handle-ref) #f)
        (check-equal? (test-ref pending 'handoff-required) #t)
        (check-equal? (test-ref pending 'declaration-checked?) #t)
        (check-equal? (test-ref pending 'root-session-declared?) #t)
        (check-equal? (test-ref pending 'session-declared?) #t)
        (check-equal? (test-ref pending 'undeclared-session-refs) '())
        (check-equal? (test-ref pending 'undeclared-parent-session-refs)
                      '())
        (check-equal? (test-ref pending 'sandbox-handle-declared?) #t)
        (check-equal? (test-ref pending 'valid?) #t)
        (check-equal? (test-ref pending 'diagnostic-count) 0)
        (check-equal? (test-ref pending 'diagnostics) '())
        (check-equal? (test-ref failed 'declaration-checked?) #t)
        (check-equal? (test-ref failed 'valid?) #t)
        (check-equal? (test-ref failed 'diagnostic-count) 0)
        (check-equal? (test-ref pending 'runtime-executed) #f)
        (check-equal? (test-ref failed 'runtime-executed) #f)))))
