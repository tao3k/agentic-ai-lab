;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof FFI bridge payload projection.
;;; - Keep gate decisions serialized explicitly before handing them to foreign runtimes.
(import :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/proof-gate-decision)

(export poo-flow-proof-gate-decision->ffi-payload
        poo-flow-proof-gate-receipts->ffi-payload
        poo-flow-langgraph-user-interface-proof-ffi-payload)

;;; Boundary: decision payloads are serialized as stable alist fields for FFI consumers.
;; : (-> ProofGateDecision ProofFfiPayload)
(def (poo-flow-proof-gate-decision->ffi-payload decision)
  (let ((bundle (poo-flow-proof-fact-ref 'bundle decision)))
    (foldr cons
           '()
           (list (cons 'schema 'poo-flow.proof.ffi-bridge.payload)
                 (cons 'version 1)
                 (cons 'accepted? (poo-flow-proof-fact-ref 'accepted? decision))
                 (cons 'runtime-boundary-ok?
                       (poo-flow-proof-fact-ref 'runtime-boundary-ok? decision))
                 (cons 'rejection-reasons
                       (poo-flow-proof-fact-ref 'rejection-reasons decision))
                 (cons 'composition-wire
                       (poo-flow-proof-fact-ref 'composition bundle))
                 (cons 'scenario-wire
                       (poo-flow-proof-fact-ref 'scenario bundle))
                 (cons 'handoff-wire
                       (poo-flow-proof-fact-ref 'handoff bundle))))))

;;; Boundary: receipt projection composes validation and FFI serialization without exposing intermediate state.
;; : (-> ProofGateReceipts ProofFfiPayload)
(def (poo-flow-proof-gate-receipts->ffi-payload receipts)
  (foldr (lambda (step value) (step value))
         receipts
         (list poo-flow-proof-gate-decision->ffi-payload
               poo-flow-proof-gate-receipts->decision)))

;;; Boundary: the LangGraph fixture enters the same FFI payload projection as user receipts.
;; : (-> ProofFfiPayload)
(def (poo-flow-langgraph-user-interface-proof-ffi-payload)
  (poo-flow-proof-gate-decision->ffi-payload
   (poo-flow-langgraph-user-interface-proof-gate-decision)))
