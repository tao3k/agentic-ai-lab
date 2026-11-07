;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof gate decision projection.
;;; - Keep rejection reasons derived from validated proof wires before runtime handoff.
(import :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/proof-gate-receipts)

(export agentic-ai-lab-proof-gate-bundle->decision
        agentic-ai-lab-proof-gate-receipts->decision
        agentic-ai-lab-proof-gate-decision-accepted?
        agentic-ai-lab-proof-gate-decision-rejection-reasons
        agentic-ai-lab-langgraph-user-interface-proof-gate-decision)

;; : (-> Symbol Alist Object)
(def (agentic-ai-lab-proof-gate-wire-rejection-reason source wire)
  (if (agentic-ai-lab-proof-fact-ref 'accepted? wire)
    #f
    (list (cons 'source source)
          (cons 'fact-schema (agentic-ai-lab-proof-fact-ref 'fact-schema wire))
          (cons 'fact-id (agentic-ai-lab-proof-fact-ref 'fact-id wire))
          (cons 'rejection-rule
                (agentic-ai-lab-proof-fact-ref 'rejection-rule wire)))))

;; : (-> Alist Object)
(def (agentic-ai-lab-proof-gate-runtime-boundary-rejection-reason bundle)
  (if (agentic-ai-lab-proof-fact-ref 'runtime-boundary-ok? bundle)
    #f
    (list (cons 'source 'runtime-boundary)
          (cons 'fact-schema 'agentic-ai-lab.proof.control-plane.handoff)
          (cons 'fact-id
                (agentic-ai-lab-proof-fact-ref
                 'fact-id
                 (agentic-ai-lab-proof-fact-ref 'handoff bundle)))
          (cons 'rejection-rule 'runtime-boundary-rejected))))

;; : (-> Object [Alist] [Alist])
(def (agentic-ai-lab-proof-gate-cons-reason reason reasons)
  (if reason
    (cons reason reasons)
    reasons))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-proof-gate-bundle-rejection-reasons bundle)
  (reverse
   (agentic-ai-lab-proof-gate-cons-reason
    (agentic-ai-lab-proof-gate-runtime-boundary-rejection-reason bundle)
    (agentic-ai-lab-proof-gate-cons-reason
     (agentic-ai-lab-proof-gate-wire-rejection-reason
      'handoff
      (agentic-ai-lab-proof-fact-ref 'handoff bundle))
     (agentic-ai-lab-proof-gate-cons-reason
      (agentic-ai-lab-proof-gate-wire-rejection-reason
       'scenario
       (agentic-ai-lab-proof-fact-ref 'scenario bundle))
      (agentic-ai-lab-proof-gate-cons-reason
       (agentic-ai-lab-proof-gate-wire-rejection-reason
        'composition
        (agentic-ai-lab-proof-fact-ref 'composition bundle))
       '()))))))

;; : (-> Alist Alist)
(def (agentic-ai-lab-proof-gate-bundle->decision bundle)
  (let ((accepted? (agentic-ai-lab-proof-fact-ref 'accepted? bundle))
        (reasons (agentic-ai-lab-proof-gate-bundle-rejection-reasons bundle)))
    (list (cons 'schema 'agentic-ai-lab.proof.gate.decision)
          (cons 'version 1)
          (cons 'accepted? accepted?)
          (cons 'runtime-boundary-ok?
                (agentic-ai-lab-proof-fact-ref 'runtime-boundary-ok? bundle))
          (cons 'rejection-reasons reasons)
          (cons 'bundle bundle))))

;; : (-> Alist Alist)
(def (agentic-ai-lab-proof-gate-receipts->decision receipts)
  (agentic-ai-lab-proof-gate-bundle->decision
   (agentic-ai-lab-proof-gate-receipts->bundle receipts)))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-proof-gate-decision-accepted? decision)
  (agentic-ai-lab-proof-fact-ref 'accepted? decision))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-proof-gate-decision-rejection-reasons decision)
  (agentic-ai-lab-proof-fact-ref 'rejection-reasons decision))

;; : (-> Alist)
(def (agentic-ai-lab-langgraph-user-interface-proof-gate-decision)
  (agentic-ai-lab-proof-gate-receipts->decision
   (agentic-ai-lab-langgraph-user-interface-proof-receipts)))
