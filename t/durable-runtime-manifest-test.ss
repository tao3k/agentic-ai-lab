;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/runtime-manifest)

(export durable-runtime-manifest-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let ((cell (assq key row)))
    (and cell (cdr cell))))

;; : TestSuite
(def durable-runtime-manifest-test
  (test-suite "agentic-ai-lab durable runtime manifest envelope"
    (yuanxu-test-case "projects policy store backend and operations into one envelope"
      (let ((manifest
             (agentic-ai-lab-durable-runtime-manifest-alist
              agentic-ai-lab-durable-policy/default
              agentic-ai-lab-durable-runtime-store-contract/default
              agentic-ai-lab-durable-runtime-store-backend/default)))
        (check-equal? (test-ref manifest 'schema)
                      +agentic-ai-lab-durable-runtime-envelope-schema+)
        (check-equal? (test-ref manifest 'owner) 'scheme)
        (check-equal? (test-ref manifest 'policy-id) 'durable/default)
        (check-equal? (test-ref manifest 'store-id) 'runtime-store/default)
        (check-equal? (test-ref manifest 'backend-id) 'runtime-backend/marlin-store)
        (check-equal? (test-ref manifest 'backend-executable) "marlin-runtime-store")
        (check-equal? (test-ref manifest 'checkpoint-store)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref manifest 'checkpoint-store-ref)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref manifest 'operation-kinds)
                      '(append-fact
                        write-checkpoint
                        rebuild-index
                        claim-job-lease
                        append-repair-event
                        retain-artifact
                        append-communication-event
                        attach-sandbox-handle))
        (check-equal? (test-ref manifest 'operation-count) 8)
        (check-equal? (test-ref manifest 'negotiate-argv)
                      '("marlin-runtime-store" "durable-runtime-store" "negotiate"))
        (check-equal? (test-ref manifest 'operations-argv)
                      '("marlin-runtime-store" "durable-runtime-store" "operations"))
        (check-equal? (test-ref manifest 'policy-valid) #t)
        (check-equal? (test-ref manifest 'store-valid) #t)
        (check-equal? (test-ref manifest 'backend-valid) #t)
        (check-equal? (test-ref manifest 'diagnostic-count) 0)
        (check-equal? (test-ref manifest 'runtime-executed) #f)))
    (yuanxu-test-case "emits byte carrier for runtime languages"
      (let* ((payload
              (agentic-ai-lab-durable-runtime-manifest-string
               (agentic-ai-lab-durable-policy 'durable/runtime 'shared)
               agentic-ai-lab-durable-runtime-store-contract/default
               agentic-ai-lab-durable-runtime-store-backend/default))
             (bytes
              (agentic-ai-lab-durable-runtime-manifest-bytes
               (agentic-ai-lab-durable-policy 'durable/runtime 'shared)
               agentic-ai-lab-durable-runtime-store-contract/default
               agentic-ai-lab-durable-runtime-store-backend/default)))
        (check-equal? (string? payload) #t)
        (check-equal? (u8vector? bytes) #t)
        (check-equal? (> (u8vector-length bytes) 0) #t)))))
