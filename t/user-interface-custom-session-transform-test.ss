;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-transform scenario.
;;; Invariant: transform rows are report-only handoff receipts; Scheme never
;;; invokes a provider, memory backend, sandbox runtime, or tool.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-flag-entry)
        :poo-flow/modules/session/config
        (only-in "../user-interface/custom/my-module/cases/session-transform"
                 poo-flow-custom-my-module-session-transform-case))

(export user-interface-custom-session-transform-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Value])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (poo-flow-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-transform-test
  (test-suite "poo-flow custom user-interface session-transform case"
    (poo-flow-test-case "projects transform declarations through session-owned syntax"
      (let* ((selection
              (car poo-flow-custom-my-module-session-transform-case))
             (rows
              (module-config-rows
               poo-flow-custom-my-module-session-transform-case))
             (memory-intent (car rows))
             (transform (cadr rows))
             (root-session (list-ref rows 2))
             (receipt (list-ref rows 3))
             (handoff-intent
              (poo-flow-session-transform-receipt-handoff-intent receipt)))
        (check-equal? (poo-flow-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (length rows) 4)
        (check-equal? (poo-flow-session-memory-intent? memory-intent) #t)
        (check-equal? (poo-flow-session-memory-intent-name memory-intent)
                      'custom/review-memory)
        (check-equal? (poo-flow-session-memory-intent-store-ref memory-intent)
                      'session/memory)
        (check-equal? (poo-flow-session-memory-intent-scope memory-intent)
                      'project-workspace)
        (check-equal? (poo-flow-session-memory-intent-recall memory-intent)
                      '(repository-summary review-notes))
        (check-equal? (poo-flow-session-memory-intent-commit-policy
                       memory-intent)
                      'commit-derived-session)
        (check-equal? (poo-flow-session-transform? transform) #t)
        (check-equal? (poo-flow-session-transform-name transform)
                      'custom-review-agent)
        (check-equal? (poo-flow-session-transform-intent transform)
                      'review)
        (check-equal? (length (poo-flow-session-transform-memory-intents
                               transform))
                      1)
        (check-equal? (poo-flow-session? root-session) #t)
        (check-equal? (poo-flow-session-id root-session)
                      'custom/session-transform-root)
        (check-equal? (poo-flow-session-transform-receipt? receipt) #t)
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
