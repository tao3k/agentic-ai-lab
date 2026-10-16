;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/proof-ffi-bridge
        :poo-flow/modules/proof/projections/proof-gate-receipts)

(def proof-ffi-bridge-test
  (test-suite "proof FFI bridge"
    (poo-flow-test-case "projects the accepted proof payload"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof ffi bridge mismatch" label actual expected)))

(def payload
  (poo-flow-langgraph-user-interface-proof-ffi-payload))

(assert-equal 'payload-schema
              (poo-flow-proof-fact-ref 'schema payload)
              'poo-flow.proof.ffi-bridge.payload)
(assert-equal 'payload-version
              (poo-flow-proof-fact-ref 'version payload)
              1)
(assert-equal 'payload-accepted
              (poo-flow-proof-fact-ref 'accepted? payload)
              #t)
(assert-equal 'composition-wire-schema
              (poo-flow-proof-fact-ref
               'schema
               (poo-flow-proof-fact-ref 'composition-wire payload))
              'poo-flow.proof.ffi-wire)
(assert-equal 'scenario-wire-schema
              (poo-flow-proof-fact-ref
               'schema
               (poo-flow-proof-fact-ref 'scenario-wire payload))
              'poo-flow.proof.ffi-wire)
(assert-equal 'handoff-wire-schema
              (poo-flow-proof-fact-ref
               'schema
               (poo-flow-proof-fact-ref 'handoff-wire payload))
              'poo-flow.proof.ffi-wire))))
