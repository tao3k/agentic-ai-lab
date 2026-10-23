;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/ai-agentic-context/features/memory/durable/store
        :poo-flow/modules/ai-agentic-context/features/memory/durable/store-backend
        :poo-flow/modules/ai-agentic-context/features/memory/durable/runtime-manifest)

(export durable-runtime-manifest-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let ((cell (assq key row)))
    (and cell (cdr cell))))

;; : TestSuite
(def durable-runtime-manifest-test
  (test-suite "poo-flow durable runtime manifest envelope"
    (yuanxu-test-case "projects policy store backend and operations into one envelope"
      (let ((manifest
             (poo-flow-durable-runtime-manifest-alist
              poo-flow-durable-policy/default
              poo-flow-durable-runtime-store-contract/default
              poo-flow-durable-runtime-store-backend/default)))
        (check-equal? (test-ref manifest 'schema)
                      +poo-flow-durable-runtime-envelope-schema+)
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
              (poo-flow-durable-runtime-manifest-string
               (poo-flow-durable-policy 'durable/runtime 'shared)
               poo-flow-durable-runtime-store-contract/default
               poo-flow-durable-runtime-store-backend/default))
             (bytes
              (poo-flow-durable-runtime-manifest-bytes
               (poo-flow-durable-policy 'durable/runtime 'shared)
               poo-flow-durable-runtime-store-contract/default
               poo-flow-durable-runtime-store-backend/default)))
        (check-equal? (string? payload) #t)
        (check-equal? (u8vector? bytes) #t)
        (check-equal? (> (u8vector-length bytes) 0) #t)))))
