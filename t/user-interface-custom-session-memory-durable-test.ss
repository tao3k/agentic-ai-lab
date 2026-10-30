;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable session-memory scenario.
;;; Invariant: durable memory rows are handoff receipts only; Scheme never
;;; recalls, commits, consolidates, persists, or repairs memory stores.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/session-memory-durable"
                 agentic-ai-lab-custom-my-module-session-memory-durable-case))

(export user-interface-custom-session-memory-durable-test)

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

;; : (-> [Alist] Symbol [Value])
(def (rows-field rows key)
  (if (null? rows)
    '()
    (cons (test-ref (car rows) key)
          (rows-field (cdr rows) key))))

;; : TestSuite
(def user-interface-custom-session-memory-durable-test
  (test-suite "agentic-ai-lab custom user-interface session-memory-durable case"
    (yuanxu-test-case "projects durable memory job receipts without runtime work"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-memory-durable-case))
             (rows
              (module-config-rows
               agentic-ai-lab-custom-my-module-session-memory-durable-case))
             (parent-summary (car rows))
             (stale-source (list-ref rows 4))
             (repair (list-ref rows 5)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (length rows) 6)
        (check-equal? (rows-field rows 'kind)
                      '(agentic-ai-lab.memory-core.durable-job-receipt
                        agentic-ai-lab.memory-core.durable-job-receipt
                        agentic-ai-lab.memory-core.durable-job-receipt
                        agentic-ai-lab.memory-core.durable-job-receipt
                        agentic-ai-lab.memory-core.durable-job-receipt
                        agentic-ai-lab.memory-core.durable-job-receipt))
        (check-equal? (rows-field rows 'job-kind)
                      '(recall write recall consolidation stale-source repair))
        (check-equal? (test-ref parent-summary 'project-id) 'custom/project)
        (check-equal? (test-ref parent-summary 'root-session-id)
                      'custom/root-session)
        (check-equal? (test-ref parent-summary 'session-id)
                      'custom/audit-session)
        (check-equal? (test-ref parent-summary 'agent-id) 'agent/audit)
        (check-equal? (test-ref parent-summary 'store-ref)
                      'memory/durable-project)
        (check-equal? (test-ref parent-summary 'durable-policy-ref)
                      'durable/custom-memory)
        (check-equal? (test-ref parent-summary 'source-watermark) 'turn/40)
        (check-equal? (test-ref parent-summary 'target-watermark)
                      'memory/index/40)
        (check-equal? (rows-field rows 'valid?)
                      '(#t #t #t #t #t #t))
        (check-equal? (rows-field rows 'diagnostic-count)
                      '(0 0 0 0 0 0))
        (check-equal? (test-ref stale-source 'stale-source?) #t)
        (check-equal? (test-ref repair 'job-state) 'repair-required)
        (check-equal? (rows-field rows 'handoff-required)
                      '(#t #t #t #t #t #t))
        (check-equal? (rows-field rows 'runtime-owner)
                      '("marlin-agent-core"
                        "marlin-agent-core"
                        "marlin-agent-core"
                        "marlin-agent-core"
                        "marlin-agent-core"
                        "marlin-agent-core"))
        (check-equal? (rows-field rows 'runtime-executed)
                      '(#f #f #f #f #f #f))))))
