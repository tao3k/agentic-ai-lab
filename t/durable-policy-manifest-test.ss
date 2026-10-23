;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy-manifest)

(export durable-policy-manifest-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let ((cell (assq key row)))
    (and cell (cdr cell))))

;; : TestSuite
(def durable-policy-manifest-test
  (test-suite "agentic-ai-lab durable policy runtime manifest"
    (yuanxu-test-case "projects Scheme durable policy receipt into runtime manifest"
      (let ((manifest
             (agentic-ai-lab-durable-policy-runtime-manifest-alist
              agentic-ai-lab-durable-policy/default)))
        (check-equal? (test-ref manifest 'schema)
                      +agentic-ai-lab-durable-runtime-policy-manifest-schema+)
        (check-equal? (test-ref manifest 'owner) 'scheme)
        (check-equal? (test-ref manifest 'policy-id) 'durable/default)
        (check-equal? (test-ref manifest 'checkpoint-id-strategy)
                      'runtime-generated)
        (check-equal? (test-ref manifest 'require-plan-digest-match) #t)
        (check-equal? (test-ref manifest 'checkpoint-store)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref manifest 'repair-mode) 'fail-closed)
        (check-equal? (test-ref manifest 'action-classes)
                      '(replayable idempotent compensatable terminal manual))
        (check-equal? (test-ref manifest 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref manifest 'receipt-schema)
                      +agentic-ai-lab-durable-policy-receipt-schema+)
        (check-equal? (test-ref manifest 'receipt-kind)
                      +agentic-ai-lab-durable-policy-kind+)
        (check-equal? (test-ref manifest 'receipt-valid) #t)
        (check-equal? (test-ref manifest 'receipt-diagnostic-count) 0)))
    (yuanxu-test-case "emits byte carrier for FFI runtime adapters"
      (let* ((policy (agentic-ai-lab-durable-policy 'durable/runtime 'shared))
             (manifest
              (agentic-ai-lab-durable-policy-runtime-manifest-alist policy))
             (payload
              (agentic-ai-lab-durable-policy-runtime-manifest-string policy))
             (bytes
              (agentic-ai-lab-durable-policy-runtime-manifest-bytes policy)))
        (check-equal? (test-ref manifest 'policy-id) 'durable/runtime)
        (check-equal? (string? payload) #t)
        (check-equal? (u8vector? bytes) #t)
        (check-equal? (> (u8vector-length bytes) 0) #t)))))
