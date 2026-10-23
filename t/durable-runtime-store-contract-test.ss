;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store contract receipts for Rust/Marlin handoff.
;;; Invariant: tests validate receipt projection only; no runtime store runs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o object?)
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/ai-agentic-context/features/memory/durable/store)

(export durable-runtime-store-contract-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol Boolean)
(def (diagnostic-code-present? diagnostics code)
  (cond
   ((null? diagnostics) #f)
   ((equal? (test-ref (car diagnostics) 'code) code) #t)
   (else
    (diagnostic-code-present? (cdr diagnostics) code))))

;; : TestSuite
(def durable-runtime-store-contract-test
  (test-suite "poo-flow durable runtime store contract"
    (yuanxu-test-case "projects runtime store contract as struct receipt then alist"
      (let* ((durable-policy
              (poo-flow-durable-policy
               'durable/runtime-store
               'objects.shared.durable
               '((journal-owner . runtime/fact-log)
                 (checkpoint-store . runtime/checkpoint-store)
                 (resume-identity . session-id)
                 (repair-mode . rebuild)
                 (action-classes . (replayable idempotent compensatable)))))
             (contract
              (poo-flow-durable-runtime-store-contract
               'runtime-store/project
               'marlin-runtime-store
               durable-policy
               '((metadata . ((case . durable-runtime-store-contract))))))
             (receipt
              (poo-flow-durable-runtime-store-contract->receipt
               contract
               '((project-id . project/poo-flow)
                 (root-session-id . session/root)
                 (session-id . session/root))))
             (row
              (poo-flow-durable-runtime-store-contract-receipt->alist
               receipt)))
        (check-equal? (poo-flow-durable-runtime-store-contract? contract) #t)
        (check-equal?
         (poo-flow-durable-runtime-store-contract-receipt? receipt)
         #t)
        (check-equal?
         (poo-flow-durable-runtime-store-contract-receipt-valid? receipt)
         #t)
        (check-equal? (test-ref row 'store-id) 'runtime-store/project)
        (check-equal? (test-ref row 'store-owner) 'marlin-runtime-store)
        (check-equal? (test-ref row 'durable-policy-ref)
                      'durable/runtime-store)
        (check-equal? (test-ref row 'project-id) 'project/poo-flow)
        (check-equal? (test-ref row 'runtime-owner) "marlin-agent-core")
        (check-equal? (test-ref row 'schema-version) 1)
        (check-equal? (test-ref row 'fact-log-ref) 'runtime/fact-log)
        (check-equal? (test-ref row 'checkpoint-store-ref)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref row 'derived-index-ref)
                      'runtime/derived-index)
        (check-equal? (test-ref row 'ledger-kinds)
                      +poo-flow-durable-runtime-store-ledger-kinds+)
        (check-equal? (test-ref row 'capability-flags)
                      +poo-flow-durable-runtime-store-capability-flags+)
        (check-equal? (test-ref row 'diagnostic-count) 0)
        (check-equal? (test-ref row 'runtime-executed) #f)))

    (yuanxu-test-case "reports missing store owner and unsupported store vocabulary"
      (let* ((invalid-policy
              (.o durable-kind: +poo-flow-durable-policy-kind+
                  durable-schema: +poo-flow-durable-policy-schema+
                  durable-policy-name: 'durable/invalid-runtime-store
                  durable-scope-ref: 'objects.shared.durable
                  repair-mode: 'teleport
                  action-classes: '(replayable impossible)
                  runtime-owner: 'not-runtime-owner))
             (contract
              (.o durable-runtime-store-kind:
                  +poo-flow-durable-runtime-store-contract-kind+
                  durable-runtime-store-schema:
                  +poo-flow-durable-runtime-store-contract-schema+
                  runtime-store-id: 'runtime-store/invalid
                  runtime-store-durable-policy: invalid-policy
                  runtime-store-schema-version: 'v1
                  runtime-store-fact-log-ref: 'runtime/fact-log
                  runtime-store-checkpoint-store-ref: 'runtime/checkpoint-store
                  runtime-store-derived-index-ref: 'runtime/derived-index
                  runtime-store-job-store-ref: 'runtime/job-store
                  runtime-store-repair-journal-ref: 'runtime/repair-journal
                  runtime-store-artifact-store-ref: 'runtime/artifact-store
                  runtime-store-communication-ledger-ref: 'runtime/communication-ledger
                  runtime-store-sandbox-ledger-ref: 'runtime/sandbox-ledger
                  runtime-store-ledger-kinds: '(fact-log impossible-ledger)
                  runtime-store-capability-flags: '(append-fact impossible-capability)
                  runtime-store-metadata: '((case . invalid-runtime-store))))
             (receipt
              (poo-flow-durable-runtime-store-contract->receipt contract))
             (row
              (poo-flow-durable-runtime-store-contract-receipt->alist
               receipt))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal?
         (poo-flow-durable-runtime-store-contract-receipt-valid? receipt)
         #f)
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (> (test-ref row 'diagnostic-count) 0) #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-store-owner)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'invalid-schema-version)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'invalid-durable-policy-receipt)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'unsupported-ledger-kind)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'unsupported-capability-flag)
         #t)))

    (yuanxu-test-case "batch projection keeps runtime boundary bounded"
      (let* ((contracts
              (list
               poo-flow-durable-runtime-store-contract/default
               (poo-flow-durable-runtime-store-contract
                'runtime-store/ci
                'marlin-runtime-store
                (poo-flow-durable-policy
                 'durable/ci
                 'objects.workflow.cicd
                 '((repair-mode . compensate)
                   (action-classes . (idempotent compensatable)))))))
             (receipts
              (poo-flow-durable-runtime-store-contracts->receipts
               contracts))
             (rows
              (poo-flow-durable-runtime-store-contract-receipts->alists
               receipts)))
        (check-equal? (length receipts) 2)
        (check-equal? (length rows) 2)
        (check-equal?
         (poo-flow-durable-runtime-store-contract-receipt? (car receipts))
         #t)
        (check-equal? (object? (car rows)) #f)
        (check-equal? (test-ref (car rows) 'schema)
                      +poo-flow-durable-runtime-store-contract-receipt-schema+)
        (check-equal? (test-ref (cadr rows) 'store-id) 'runtime-store/ci)
        (check-equal? (test-ref (cadr rows) 'runtime-executed) #f)))))
