;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-transform scenario.
;;; Invariant: transform rows are report-only handoff receipts; Scheme never
;;; invokes a provider, memory backend, sandbox runtime, or tool.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        :agentic-ai-lab/modules/session/config
        (only-in "../user-interface/custom/my-module/cases/session-transform"
                 agentic-ai-lab-custom-my-module-session-transform-case))

(export user-interface-custom-session-transform-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Value])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-transform-test
  (test-suite "agentic-ai-lab custom user-interface session-transform case"
    (yuanxu-test-case "projects transform declarations through session-owned syntax"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-transform-case))
             (rows
              (module-config-rows
               agentic-ai-lab-custom-my-module-session-transform-case))
             (memory-intent (car rows))
             (transform (cadr rows))
             (root-session (list-ref rows 2))
             (receipt (list-ref rows 3))
             (handoff-intent
              (agentic-ai-lab-session-transform-receipt-handoff-intent receipt)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (length rows) 4)
        (check-equal? (agentic-ai-lab-session-memory-intent? memory-intent) #t)
        (check-equal? (agentic-ai-lab-session-memory-intent-name memory-intent)
                      'custom/review-memory)
        (check-equal? (agentic-ai-lab-session-memory-intent-store-ref memory-intent)
                      'session/memory)
        (check-equal? (agentic-ai-lab-session-memory-intent-scope memory-intent)
                      'project-workspace)
        (check-equal? (agentic-ai-lab-session-memory-intent-recall memory-intent)
                      '(repository-summary review-notes))
        (check-equal? (agentic-ai-lab-session-memory-intent-commit-policy
                       memory-intent)
                      'commit-derived-session)
        (check-equal? (agentic-ai-lab-session-transform? transform) #t)
        (check-equal? (agentic-ai-lab-session-transform-name transform)
                      'custom-review-agent)
        (check-equal? (agentic-ai-lab-session-transform-intent transform)
                      'review)
        (check-equal? (length (agentic-ai-lab-session-transform-memory-intents
                               transform))
                      1)
        (check-equal? (agentic-ai-lab-session? root-session) #t)
        (check-equal? (agentic-ai-lab-session-id root-session)
                      'custom/session-transform-root)
        (check-equal? (agentic-ai-lab-session-transform-receipt? receipt) #t)
        (check-equal? (.ref receipt 'transform-name) 'custom-review-agent)
        (check-equal? (.ref receipt 'source-session-id)
                      'custom/session-transform-root)
        (check-equal? (.ref receipt 'derived-session-id)
                      'custom/session-transform-review)
        (check-equal? (.ref receipt 'derived-session-branch-kind)
                      'transform)
        (check-equal? (.ref receipt 'memory-receipt-count) 1)
        (check-equal? (test-ref handoff-intent 'memory-intent-count) 1)
        (check-equal? (test-ref handoff-intent 'runtime-executed) #f)
        (check-equal? (.ref receipt 'runtime-executed) #f)))))
