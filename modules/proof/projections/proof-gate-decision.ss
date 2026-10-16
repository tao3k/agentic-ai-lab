;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof gate decision projection.
;;; - Keep rejection reasons derived from validated proof wires before runtime handoff.
(import :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/proof-gate-receipts)

(export poo-flow-proof-gate-bundle->decision
        poo-flow-proof-gate-receipts->decision
        poo-flow-proof-gate-decision-accepted?
        poo-flow-proof-gate-decision-rejection-reasons
        poo-flow-langgraph-user-interface-proof-gate-decision)

;; : (-> Symbol Alist Object)
(def (poo-flow-proof-gate-wire-rejection-reason source wire)
  (if (poo-flow-proof-fact-ref 'accepted? wire)
    #f
    (list (cons 'source source)
          (cons 'fact-schema (poo-flow-proof-fact-ref 'fact-schema wire))
          (cons 'fact-id (poo-flow-proof-fact-ref 'fact-id wire))
          (cons 'rejection-rule
                (poo-flow-proof-fact-ref 'rejection-rule wire)))))

;; : (-> Alist Object)
(def (poo-flow-proof-gate-runtime-boundary-rejection-reason bundle)
  (if (poo-flow-proof-fact-ref 'runtime-boundary-ok? bundle)
    #f
    (list (cons 'source 'runtime-boundary)
          (cons 'fact-schema 'poo-flow.proof.control-plane.handoff)
          (cons 'fact-id
                (poo-flow-proof-fact-ref
                 'fact-id
                 (poo-flow-proof-fact-ref 'handoff bundle)))
          (cons 'rejection-rule 'runtime-boundary-rejected))))

;; : (-> Object [Alist] [Alist])
(def (poo-flow-proof-gate-cons-reason reason reasons)
  (if reason
    (cons reason reasons)
    reasons))

;; : (-> Alist [Alist])
(def (poo-flow-proof-gate-bundle-rejection-reasons bundle)
  (reverse
   (poo-flow-proof-gate-cons-reason
    (poo-flow-proof-gate-runtime-boundary-rejection-reason bundle)
    (poo-flow-proof-gate-cons-reason
     (poo-flow-proof-gate-wire-rejection-reason
      'handoff
      (poo-flow-proof-fact-ref 'handoff bundle))
     (poo-flow-proof-gate-cons-reason
      (poo-flow-proof-gate-wire-rejection-reason
       'scenario
       (poo-flow-proof-fact-ref 'scenario bundle))
      (poo-flow-proof-gate-cons-reason
       (poo-flow-proof-gate-wire-rejection-reason
        'composition
        (poo-flow-proof-fact-ref 'composition bundle))
       '()))))))

;; : (-> Alist Alist)
(def (poo-flow-proof-gate-bundle->decision bundle)
  (let ((accepted? (poo-flow-proof-fact-ref 'accepted? bundle))
        (reasons (poo-flow-proof-gate-bundle-rejection-reasons bundle)))
    (list (cons 'schema 'poo-flow.proof.gate.decision)
          (cons 'version 1)
          (cons 'accepted? accepted?)
          (cons 'runtime-boundary-ok?
                (poo-flow-proof-fact-ref 'runtime-boundary-ok? bundle))
          (cons 'rejection-reasons reasons)
          (cons 'bundle bundle))))

;; : (-> Alist Alist)
(def (poo-flow-proof-gate-receipts->decision receipts)
  (poo-flow-proof-gate-bundle->decision
   (poo-flow-proof-gate-receipts->bundle receipts)))

;; : (-> Alist Boolean)
(def (poo-flow-proof-gate-decision-accepted? decision)
  (poo-flow-proof-fact-ref 'accepted? decision))

;; : (-> Alist [Alist])
(def (poo-flow-proof-gate-decision-rejection-reasons decision)
  (poo-flow-proof-fact-ref 'rejection-reasons decision))

;; : (-> Alist)
(def (poo-flow-langgraph-user-interface-proof-gate-decision)
  (poo-flow-proof-gate-receipts->decision
   (poo-flow-langgraph-user-interface-proof-receipts)))
