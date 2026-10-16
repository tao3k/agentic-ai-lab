;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: projects bounded AC-08 proof facts from authorized-effect evidence.
;;; Invariant: proof projection never invents observations or raises claim level.
(import (only-in :clan/poo/object .o .ref))

(export poo-flow-authorized-effect-proof-facts
        poo-flow-authorized-effect-proof-claim-level
        poo-flow-authorized-effect-proof-facts->ffi-wire)

;; : (-> PooFlowAuthorizedEffectProofFacts PooFlowAuthorizedEffectClaimLevel)
(def (poo-flow-authorized-effect-proof-claim-level facts)
  (match (cond
          ((and (.ref facts 'l2-ready?)
                (.ref facts 'durable-evidence-reference)
                (.ref facts 'kernel-signature)
                (.ref facts 'signature-verified?)
                (.ref facts 'inclusion-proof-verified?)) 'l3)
          ((.ref facts 'l2-ready?) 'l2)
          ((and (.ref facts 'decision-permit?)
                (.ref facts 'semantic-root-bound?)
                (.ref facts 'token-consumed?)) 'l1)
          (else 'unverified))
    ('l3 'l3-verified)
    ('l2 'l2-evidenced)
    ('l1 'l1-mediated)
    (else 'unverified)))

;; : (-> PooFlowFactId Boolean Boolean Boolean Boolean Boolean Symbol Symbol Object Object Boolean Boolean PooFlowAuthorizedEffectProofFacts)
(def (poo-flow-authorized-effect-proof-facts
      identity decision-permit semantic-bound token-consumed root-linked
      adapter-observed effect-outcome durability-profile evidence-reference
      kernel-attestation signature-verified inclusion-proof-verified)
  (let (l2-ready
        (and decision-permit semantic-bound token-consumed root-linked
             adapter-observed (eq? effect-outcome 'committed)
             (memq durability-profile '(strict batched))))
    (.o (kind 'poo-flow-authorized-effect-proof-facts)
        (schema 'poo-flow.proof.authorized-effect.draft.1)
        (fact-id identity)
        (decision-permit? decision-permit)
        (semantic-root-bound? semantic-bound)
        (token-consumed? token-consumed)
        (execution-root-linked? root-linked)
        (adapter-observed? adapter-observed)
        (outcome effect-outcome)
        (durability durability-profile)
        (durable-evidence-reference evidence-reference)
        (kernel-signature kernel-attestation)
        (signature-verified? signature-verified)
        (inclusion-proof-verified? inclusion-proof-verified)
        (l2-ready? l2-ready))))

;; : (forall (v) (-> v [(Pair Symbol v)]))
;; : (-> PooFlowAuthorizedEffectProofFacts Alist)
(def (poo-flow-authorized-effect-proof-facts->ffi-wire facts)
  (let (claim-level (poo-flow-authorized-effect-proof-claim-level facts))
    (map cons
         '(schema
           version
           fact-id
           claim-level
           accepted?
           decision-permit?
           semantic-root-bound?
           token-consumed?
           execution-root-linked?
           adapter-observed?
           outcome
           durability
           durable-evidence-reference
           kernel-signature
           signature-verified?
           inclusion-proof-verified?)
         (list 'poo-flow.proof.authorized-effect.ffi-wire
               1
               (.ref facts 'fact-id)
               claim-level
               (memq claim-level '(l2-evidenced l3-verified))
               (.ref facts 'decision-permit?)
               (.ref facts 'semantic-root-bound?)
               (.ref facts 'token-consumed?)
               (.ref facts 'execution-root-linked?)
               (.ref facts 'adapter-observed?)
               (.ref facts 'outcome)
               (.ref facts 'durability)
               (.ref facts 'durable-evidence-reference)
               (.ref facts 'kernel-signature)
               (.ref facts 'signature-verified?)
               (.ref facts 'inclusion-proof-verified?)))))
