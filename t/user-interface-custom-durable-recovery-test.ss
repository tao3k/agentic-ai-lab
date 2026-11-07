;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable recovery scenario.
;;; Invariant: recovery rows describe crash/replay/repair handoff data only;
;;; Scheme never replays logs, claims leases, repairs state, or runs workflow.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/durable-recovery"
                 agentic-ai-lab-custom-my-module-durable-recovery-case))

(export user-interface-custom-durable-recovery-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-durable-recovery-test
  (test-suite "agentic-ai-lab custom user-interface durable-recovery case"
    (yuanxu-test-case "projects custom durable recovery handoff row"
      (let* ((row agentic-ai-lab-custom-my-module-durable-recovery-case)
             (observability-rows (test-ref row 'observability-rows)))
        (check-equal? (test-ref row 'kind)
                      'agentic-ai-lab.durable.recovery-scenario)
        (check-equal? (test-ref row 'scenario-id)
                      'recovery-scenario/custom-build-audit)
        (check-equal? (test-ref row 'valid?) #t)
        (check-equal? (test-ref row 'diagnostic-count) 0)
        (check-equal? (test-ref row 'deterministic-replay?) #t)
        (check-equal? (length observability-rows) 6)
        (check-equal? (map (lambda (entry)
                             (test-ref entry 'runtime-executed))
                           observability-rows)
                      '(#f #f #f #f #f #f))
        (check-equal? (test-ref row 'handoff-required) #t)
        (check-equal? (test-ref row 'runtime-executed) #f)))))
