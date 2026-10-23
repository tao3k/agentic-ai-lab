;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/proof-ffi-bridge
        :agentic-ai-lab/modules/proof/projections/proof-gate-receipts)

(def proof-ffi-bridge-test
  (test-suite "proof FFI bridge"
    (yuanxu-test-case "projects the accepted proof payload"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof ffi bridge mismatch" label actual expected)))

(def payload
  (agentic-ai-lab-langgraph-user-interface-proof-ffi-payload))

(assert-equal 'payload-schema
              (agentic-ai-lab-proof-fact-ref 'schema payload)
              'agentic-ai-lab.proof.ffi-bridge.payload)
(assert-equal 'payload-version
              (agentic-ai-lab-proof-fact-ref 'version payload)
              1)
(assert-equal 'payload-accepted
              (agentic-ai-lab-proof-fact-ref 'accepted? payload)
              #t)
(assert-equal 'composition-wire-schema
              (agentic-ai-lab-proof-fact-ref
               'schema
               (agentic-ai-lab-proof-fact-ref 'composition-wire payload))
              'agentic-ai-lab.proof.ffi-wire)
(assert-equal 'scenario-wire-schema
              (agentic-ai-lab-proof-fact-ref
               'schema
               (agentic-ai-lab-proof-fact-ref 'scenario-wire payload))
              'agentic-ai-lab.proof.ffi-wire)
(assert-equal 'handoff-wire-schema
              (agentic-ai-lab-proof-fact-ref
               'schema
               (agentic-ai-lab-proof-fact-ref 'handoff-wire payload))
              'agentic-ai-lab.proof.ffi-wire))))
