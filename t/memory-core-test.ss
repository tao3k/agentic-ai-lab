;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native memory specs and catalog validation.
;;; Invariant: Scheme builds memory handoff receipts only; no backend runs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :poo-flow/modules/session/config
        :poo-flow/modules/ai-agentic-context/features/memory/config
        (only-in :poo-flow/modules/ai-agentic-context/features/memory/objects-core
                 poo-flow-memory-field-rows))

(export memory-core-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

(def memory-core-test
  (test-suite "poo-flow memory-core"
    (yuanxu-test-case "expands ordered memory field rows"
      (check-equal?
       (poo-flow-memory-field-rows
        (kind 'memory)
        (schema 'memory.v1))
       '((kind . memory) (schema . memory.v1))))
    (yuanxu-test-case "authors custom memory store specs and projects handoff manifests"
      (let* ((store
              (poo-flow-memory-store-spec
               'memory/project-notes
               'durable-project
               'project
               '(current-session project)
               '(semantic-search exact-key)
               '(append review-only)
               "marlin-agent-core"
               'memory/project-notes
               #t
               'marlin-memory-adapter
               '((source . unit-test))))
             (catalog
              (poo-flow-memory-catalog
               'memory-core/custom
               (list store)
               '((scope . unit-test))))
             (manifest
              (poo-flow-memory-handoff-manifest->alist
               (poo-flow-memory-handoff-manifest
                'request/project-notes
                store))))
        (check-equal? (poo-flow-memory-catalog? catalog) #t)
        (check-equal? (poo-flow-memory-catalog-ref catalog)
                      'memory-core/custom)
        (check-equal? (poo-flow-memory-catalog-store-refs catalog)
                      '(memory/project-notes))
        (check-equal? (test-ref manifest 'store-ref)
                      'memory/project-notes)
        (check-equal? (test-ref manifest 'handoff-ready?) #t)
        (check-equal? (test-ref manifest 'runtime-executed) #f)))
    (yuanxu-test-case "projects default memory stores without runtime execution"
      (let* ((catalog poo-flow-ai-agentic-context-memory-default-catalog)
             (local-store
              (poo-flow-memory-catalog-find catalog 'memory/local-session))
             (durable-store
              (poo-flow-memory-catalog-find catalog 'memory/durable-project))
             (row
              (poo-flow-memory-handoff-manifest->alist
               (poo-flow-memory-handoff-manifest
                'request/durable-project
                durable-store))))
        (check-equal? (poo-flow-memory-store-spec? local-store) #t)
        (check-equal? (poo-flow-memory-store-spec? durable-store) #t)
        (check-equal? (test-ref row 'durable?) #t)
        (check-equal? (test-ref row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "validates session memory intents against concrete store specs"
      (let* ((store
              (poo-flow-memory-store-spec
               'memory/project-notes
               'durable-project
               'project
               '(current-session project)
               '(semantic-search)
               '(append review-only)
               "marlin-agent-core"
               'memory/project-notes
               #t
               'marlin-memory-adapter))
             (no-recall-store
              (poo-flow-memory-store-spec
               'memory/no-recall
               'local-session
               'session
               '(current-session)
               '()
               '(ephemeral)
               "marlin-agent-core"
               'memory/no-recall
               #f
               'marlin-memory-adapter))
             (catalog
              (poo-flow-memory-catalog
               'memory-core/test
               (list store no-recall-store)))
             (valid-intent
              (poo-flow-session-memory-intent
               'intent/project-notes
               'memory/project-notes
               'project
               '(current-ticket)
               'append))
             (missing-intent
              (poo-flow-session-memory-intent
               'intent/missing
               'memory/missing
               'project
               '(current-ticket)
               'append))
             (bad-scope-intent
              (poo-flow-session-memory-intent
               'intent/bad-scope
               'memory/project-notes
               'sibling-session
               '()
               'append))
             (bad-commit-intent
              (poo-flow-session-memory-intent
               'intent/bad-commit
               'memory/project-notes
               'project
               '()
               'overwrite))
             (recall-disabled-intent
              (poo-flow-session-memory-intent
               'intent/recall-disabled
               'memory/no-recall
               'current-session
               '(latest)
               'ephemeral))
             (receipt
              (poo-flow-memory-policy-catalog-validation-receipt
               'validation/memory-core
               catalog
               (list valid-intent
                     missing-intent
                     bad-scope-intent
                     bad-commit-intent
                     recall-disabled-intent)))
             (row
              (poo-flow-memory-policy-catalog-validation-receipt->alist
               receipt)))
        (check-equal?
         (poo-flow-memory-policy-catalog-validation-receipt? receipt)
         #t)
        (check-equal?
         (poo-flow-memory-policy-catalog-validation-receipt-valid? receipt)
         #f)
        (check-equal? (test-ref row 'resolved-store-refs)
                      '(memory/project-notes memory/no-recall))
        (check-equal? (test-ref row 'unresolved-store-refs)
                      '(memory/missing))
        (check-equal? (test-field-values (test-ref row 'diagnostics) 'code)
                      '(memory-store-not-in-catalog
                        memory-intent-scope-denied
                        memory-intent-commit-denied
                        memory-store-recall-disabled))
        (check-equal? (test-ref row 'runtime-executed) #f)))))
