;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store backend negotiation for Marlin handoff.
;;; Invariant: tests validate backend selection and ABI projection only; no
;;; runtime store process is started.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o object?)
        :yuanxu/modules/funflow/control-plane/runtime-protocol
        :yuanxu/modules/funflow/control-plane/runtime-adapter
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend)

(export durable-runtime-store-backend-test)

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

;; : (-> PooDurableRuntimeStoreContractReceipt)
(def (test-runtime-store-contract-receipt)
  (agentic-ai-lab-durable-runtime-store-contract->receipt
   (agentic-ai-lab-durable-runtime-store-contract
    'runtime-store/project
    'marlin-runtime-store
    (agentic-ai-lab-durable-policy
     'durable/runtime-store
     'objects.shared.durable
     '((journal-owner . runtime/fact-log)
       (checkpoint-store . runtime/checkpoint-store)
       (resume-identity . session-id)
       (repair-mode . rebuild)
       (action-classes . (replayable idempotent compensatable)))))
   '((project-id . project/agentic-ai-lab)
     (root-session-id . session/root)
     (session-id . session/root))))

;; : TestSuite
(def durable-runtime-store-backend-test
  (test-suite "agentic-ai-lab durable runtime store backend"
    (yuanxu-test-case "selects a Marlin backend and emits runtime command handoff"
      (let* ((contract-receipt (test-runtime-store-contract-receipt))
             (backend-receipt
              (agentic-ai-lab-durable-runtime-store-backend->receipt
               agentic-ai-lab-durable-runtime-store-backend/default))
             (negotiation
              (agentic-ai-lab-durable-runtime-store-backend-negotiation
               contract-receipt
               backend-receipt
               '((metadata . ((case . runtime-store-backend))))))
             (row
              (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
               negotiation))
             (handoff
              (agentic-ai-lab-durable-runtime-store-negotiation->marlin-handoff
               negotiation))
             (manifest (test-ref handoff 'runtime-command-manifest)))
        (check-equal? (agentic-ai-lab-durable-runtime-store-backend?
                       agentic-ai-lab-durable-runtime-store-backend/default)
                      #t)
        (check-equal?
         (agentic-ai-lab-durable-runtime-store-backend-receipt? backend-receipt)
         #t)
        (check-equal?
         (agentic-ai-lab-durable-runtime-store-negotiation-receipt? negotiation)
         #t)
        (check-equal? (object? row) #f)
        (check-equal? (test-ref row 'valid?) #t)
        (check-equal? (test-ref row 'selected?) #t)
        (check-equal? (test-ref row 'handoff-ready?) #t)
        (check-equal? (test-ref row 'store-id) 'runtime-store/project)
        (check-equal? (test-ref row 'backend-id)
                      'runtime-backend/marlin-store)
        (check-equal? (test-ref row 'missing-ledger-kinds) '())
        (check-equal? (test-ref row 'missing-capability-flags) '())
        (check-equal? (test-ref row 'unsupported-operation-kinds) '())
        (check-equal? (test-ref row 'diagnostic-count) 0)
        (check-equal? (test-ref handoff 'kind)
                      'agentic-ai-lab.durable.runtime-store.marlin-handoff)
        (check-equal? (test-ref handoff 'operation)
                      'durable-runtime-store-negotiate)
        (check-equal? (test-ref handoff 'request-schema)
                      +runtime-request-schema+)
        (check-equal? (test-ref handoff 'handoff-ready?) #t)
        (check-equal? (test-ref manifest 'operation)
                      'durable-runtime-store-negotiate)
        (check-equal? (test-ref manifest 'executable)
                      "marlin-runtime-store")
        (check-equal? (test-ref manifest 'argv)
                      '("marlin-runtime-store"
                        "durable-runtime-store"
                        "negotiate"))
        (check-equal? (test-ref handoff 'runtime-executed) #f)
        (check-equal? (test-ref handoff 'runtime-parses-scheme-source) #f)
        (check-equal? (test-ref handoff 'scheme-manufactures-runtime-handlers)
                      #f)))

    (yuanxu-test-case "declares Turso concurrency and AI backend capabilities"
      (let* ((backend-receipt
              (agentic-ai-lab-durable-runtime-store-backend->receipt
               agentic-ai-lab-durable-runtime-store-backend/turso))
             (row
              (agentic-ai-lab-durable-runtime-store-backend-receipt->alist
               backend-receipt))
             (metadata (test-ref row 'metadata)))
        (check-equal? (test-ref row 'backend-id) 'runtime-backend/turso)
        (check-equal? (test-ref row 'backend-kind) 'turso-runtime-store)
        (check-equal? (test-ref row 'protocol) 'python-pyturso)
        (check-equal?
         (memq 'concurrent-writes
               (test-ref row 'supported-capability-flags))
         '(concurrent-writes
           local-first-push-pull
           ai-vector-search
           libsql-vector-index
           vector-top-k))
        (check-equal?
         (memq 'ai-vector-search
               (test-ref row 'supported-capability-flags))
         '(ai-vector-search libsql-vector-index vector-top-k))
        (check-equal? (test-ref metadata 'driver) 'turso)
        (check-equal? (test-ref metadata 'driver-package) 'pyturso)
        (check-equal? (test-ref metadata 'connection-module) 'turso)
        (check-equal? (test-ref metadata 'concurrent-writes) #t)
        (check-equal? (test-ref metadata 'sync-model)
                      'local-first-push-pull)
        (check-equal? (test-ref metadata 'ai-vector-search) #t)
        (check-equal? (test-ref metadata 'vector-index)
                      'libsql_vector_idx)
        (check-equal? (test-ref metadata 'vector-query) 'vector_top_k)))

    (yuanxu-test-case "rejects a backend that cannot satisfy durable store contract"
      (let* ((backend
              (agentic-ai-lab-durable-runtime-store-backend
               'runtime-backend/weak
               'marlin-runtime-store
               "marlin-runtime-store"
               'stdout-s-expression
               '(fact-log)
               '(append-fact)
               '(append-fact)))
             (negotiation
              (agentic-ai-lab-durable-runtime-store-backend-negotiation
               (test-runtime-store-contract-receipt)
               (agentic-ai-lab-durable-runtime-store-backend->receipt backend)))
             (row
              (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
               negotiation))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (test-ref row 'selected?) #f)
        (check-equal? (test-ref row 'handoff-ready?) #f)
        (check-equal? (test-ref row 'missing-ledger-kinds)
                      '(checkpoint derived-index job repair artifact
                        communication sandbox))
        (check-equal? (test-ref row 'missing-capability-flags)
                      '(write-checkpoint rebuild-index claim-job-lease
                        append-repair-event retain-artifact
                        append-communication-event attach-sandbox-handle))
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-ledger-kinds)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'missing-capability-flags)
         #t)
        (check-equal?
         (diagnostic-code-present? diagnostics 'unsupported-operation-kinds)
         #t)))

    (yuanxu-test-case "keeps invalid store contracts out of backend selection"
      (let* ((invalid-contract
              (.o durable-runtime-store-kind:
                  +agentic-ai-lab-durable-runtime-store-contract-kind+
                  durable-runtime-store-schema:
                  +agentic-ai-lab-durable-runtime-store-contract-schema+
                  runtime-store-id: 'runtime-store/invalid
                  runtime-store-owner: #f
                  runtime-store-durable-policy: agentic-ai-lab-durable-policy/default
                  runtime-store-schema-version: 1
                  runtime-store-fact-log-ref: 'runtime/fact-log
                  runtime-store-checkpoint-store-ref: 'runtime/checkpoint-store
                  runtime-store-derived-index-ref: 'runtime/derived-index
                  runtime-store-job-store-ref: 'runtime/job-store
                  runtime-store-repair-journal-ref: 'runtime/repair-journal
                  runtime-store-artifact-store-ref: 'runtime/artifact-store
                  runtime-store-communication-ledger-ref:
                  'runtime/communication-ledger
                  runtime-store-sandbox-ledger-ref: 'runtime/sandbox-ledger
                  runtime-store-ledger-kinds:
                  +agentic-ai-lab-durable-runtime-store-ledger-kinds+
                  runtime-store-capability-flags:
                  +agentic-ai-lab-durable-runtime-store-capability-flags+
                  runtime-store-metadata: '()))
             (contract-receipt
              (agentic-ai-lab-durable-runtime-store-contract->receipt
               invalid-contract))
             (negotiation
              (agentic-ai-lab-durable-runtime-store-backend-negotiation
               contract-receipt
               (agentic-ai-lab-durable-runtime-store-backend->receipt
                agentic-ai-lab-durable-runtime-store-backend/default)))
             (row
              (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
               negotiation))
             (diagnostics (test-ref row 'diagnostics)))
        (check-equal? (test-ref row 'valid?) #f)
        (check-equal? (test-ref row 'selected?) #f)
        (check-equal? (test-ref row 'handoff-ready?) #f)
        (check-equal?
         (diagnostic-code-present? diagnostics 'runtime-store-contract-not-ready)
         #t)))))
