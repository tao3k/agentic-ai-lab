;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Strict mediation owns pure nonce/root state transitions.
;;; Invariant: a token is consumed at most once and roots never fork silently.
(import (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token)

(export agentic-ai-lab-strict-mediation-state
        agentic-ai-lab-strict-mediate
        agentic-ai-lab-strict-mediation-result-state
        agentic-ai-lab-strict-mediation-result-receipt)

(def (agentic-ai-lab-strict-mediation-state root seq spent revocation)
  (.o (kind 'agentic-ai-lab-strict-mediation-state)
      (execution-root root) (sequence seq)
      (consumed-nonces spent) (revocation-epoch revocation)
      (durability 'strict)))

(def (transition current-state receipt-value)
  (.o (kind 'agentic-ai-lab-strict-mediation-result)
      (state current-state) (receipt receipt-value)))

(def (negative-receipt reason current-state effect-token)
  (.o (kind 'agentic-ai-lab-strict-mediation-receipt)
      (accepted? #f) (outcome 'rejected) (code reason)
      (token-id (.ref effect-token 'token-id)) (nonce (.ref effect-token 'nonce))
      (before-root (.ref current-state 'execution-root))
      (after-root (.ref current-state 'execution-root))
      (durability 'strict)))

(def (agentic-ai-lab-strict-mediate state token validation-context expected-root
                               observation)
  (cond
   ((not (equal? expected-root (.ref state 'execution-root)))
    (transition state (negative-receipt 'execution-root-fork state token)))
   (else
    (let (validation
          (agentic-ai-lab-authorized-effect-token-validate token validation-context))
      (if (not (.ref validation 'accepted?))
        (transition state (negative-receipt (.ref validation 'code) state token))
        (if (not observation)
          (let* ((token-nonce (.ref token 'nonce))
                 (next-state
                  (agentic-ai-lab-strict-mediation-state
                   (.ref state 'execution-root) (+ 1 (.ref state 'sequence))
                   (cons token-nonce (.ref state 'consumed-nonces))
                   (.ref state 'revocation-epoch)))
                 (receipt
                  (.o (kind 'agentic-ai-lab-strict-mediation-receipt)
                      (accepted? #t) (outcome 'indeterminate)
                      (code 'observation-unavailable)
                      (token-id (.ref token 'token-id)) (nonce token-nonce)
                      (before-root (.ref state 'execution-root))
                      (after-root (.ref state 'execution-root))
                      (durability 'strict))))
            (transition next-state receipt))
          (let* ((consumption-receipt
                  (agentic-ai-lab-authorized-effect-token-consume
                   token validation (.ref state 'execution-root) observation))
                 (token-nonce (.ref token 'nonce))
                 (next-state
                  (agentic-ai-lab-strict-mediation-state
                   (.ref consumption-receipt 'execution-root)
                   (+ 1 (.ref state 'sequence))
                   (cons token-nonce (.ref state 'consumed-nonces))
                   (.ref state 'revocation-epoch)))
                 (receipt
                  (.o (kind 'agentic-ai-lab-strict-mediation-receipt)
                      (accepted? #t) (outcome 'committed) (code 'root-committed)
                      (token-id (.ref token 'token-id)) (nonce token-nonce)
                      (before-root (.ref state 'execution-root))
                      (after-root (.ref consumption-receipt 'execution-root))
                      (consumption consumption-receipt) (durability 'strict))))
            (transition next-state receipt)))))))
  )

(def (agentic-ai-lab-strict-mediation-result-state result)
  (.ref result 'state))

(def (agentic-ai-lab-strict-mediation-result-receipt result)
  (.ref result 'receipt))
