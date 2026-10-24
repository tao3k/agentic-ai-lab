;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof FFI bridge payload projection.
;;; - Keep gate decisions serialized explicitly before handing them to foreign runtimes.
(import :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/proof-gate-decision)

(export agentic-ai-lab-proof-gate-decision->ffi-payload
        agentic-ai-lab-proof-gate-receipts->ffi-payload
        agentic-ai-lab-langgraph-user-interface-proof-ffi-payload)

;;; Boundary: decision payloads are serialized as stable alist fields for FFI consumers.
;; : (-> ProofGateDecision ProofFfiPayload)
(def (agentic-ai-lab-proof-gate-decision->ffi-payload decision)
  (let ((bundle (agentic-ai-lab-proof-fact-ref 'bundle decision)))
    (foldr cons
           '()
           (list (cons 'schema 'agentic-ai-lab.proof.ffi-bridge.payload)
                 (cons 'version 1)
                 (cons 'accepted? (agentic-ai-lab-proof-fact-ref 'accepted? decision))
                 (cons 'runtime-boundary-ok?
                       (agentic-ai-lab-proof-fact-ref 'runtime-boundary-ok? decision))
                 (cons 'rejection-reasons
                       (agentic-ai-lab-proof-fact-ref 'rejection-reasons decision))
                 (cons 'composition-wire
                       (agentic-ai-lab-proof-fact-ref 'composition bundle))
                 (cons 'scenario-wire
                       (agentic-ai-lab-proof-fact-ref 'scenario bundle))
                 (cons 'handoff-wire
                       (agentic-ai-lab-proof-fact-ref 'handoff bundle))))))

;;; Boundary: receipt projection composes validation and FFI serialization without exposing intermediate state.
;; : (-> ProofGateReceipts ProofFfiPayload)
(def (agentic-ai-lab-proof-gate-receipts->ffi-payload receipts)
  (foldr (lambda (step value) (step value))
         receipts
         (list agentic-ai-lab-proof-gate-decision->ffi-payload
               agentic-ai-lab-proof-gate-receipts->decision)))

;;; Boundary: the LangGraph fixture enters the same FFI payload projection as user receipts.
;; : (-> ProofFfiPayload)
(def (agentic-ai-lab-langgraph-user-interface-proof-ffi-payload)
  (agentic-ai-lab-proof-gate-decision->ffi-payload
   (agentic-ai-lab-langgraph-user-interface-proof-gate-decision)))
