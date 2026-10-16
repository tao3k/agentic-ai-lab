;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Strict mediation owns pure nonce/root state transitions.
;;; Invariant: a token is consumed at most once and roots never fork silently.
(import (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/governance/policy/authorized-effect-token)

(export poo-flow-strict-mediation-state
        poo-flow-strict-mediate
        poo-flow-strict-mediation-result-state
        poo-flow-strict-mediation-result-receipt)

(def (poo-flow-strict-mediation-state root seq spent revocation)
  (.o (kind 'poo-flow-strict-mediation-state)
      (execution-root root) (sequence seq)
      (consumed-nonces spent) (revocation-epoch revocation)
      (durability 'strict)))

(def (transition current-state receipt-value)
  (.o (kind 'poo-flow-strict-mediation-result)
      (state current-state) (receipt receipt-value)))

(def (negative-receipt reason current-state effect-token)
  (.o (kind 'poo-flow-strict-mediation-receipt)
      (accepted? #f) (outcome 'rejected) (code reason)
      (token-id (.ref effect-token 'token-id)) (nonce (.ref effect-token 'nonce))
      (before-root (.ref current-state 'execution-root))
      (after-root (.ref current-state 'execution-root))
      (durability 'strict)))

(def (poo-flow-strict-mediate state token validation-context expected-root
                               observation)
  (cond
   ((not (equal? expected-root (.ref state 'execution-root)))
    (transition state (negative-receipt 'execution-root-fork state token)))
   (else
    (let (validation
          (poo-flow-authorized-effect-token-validate token validation-context))
      (if (not (.ref validation 'accepted?))
        (transition state (negative-receipt (.ref validation 'code) state token))
        (if (not observation)
          (let* ((token-nonce (.ref token 'nonce))
                 (next-state
                  (poo-flow-strict-mediation-state
                   (.ref state 'execution-root) (+ 1 (.ref state 'sequence))
                   (cons token-nonce (.ref state 'consumed-nonces))
                   (.ref state 'revocation-epoch)))
                 (receipt
                  (.o (kind 'poo-flow-strict-mediation-receipt)
                      (accepted? #t) (outcome 'indeterminate)
                      (code 'observation-unavailable)
                      (token-id (.ref token 'token-id)) (nonce token-nonce)
                      (before-root (.ref state 'execution-root))
                      (after-root (.ref state 'execution-root))
                      (durability 'strict))))
            (transition next-state receipt))
          (let* ((consumption-receipt
                  (poo-flow-authorized-effect-token-consume
                   token validation (.ref state 'execution-root) observation))
                 (token-nonce (.ref token 'nonce))
                 (next-state
                  (poo-flow-strict-mediation-state
                   (.ref consumption-receipt 'execution-root)
                   (+ 1 (.ref state 'sequence))
                   (cons token-nonce (.ref state 'consumed-nonces))
                   (.ref state 'revocation-epoch)))
                 (receipt
                  (.o (kind 'poo-flow-strict-mediation-receipt)
                      (accepted? #t) (outcome 'committed) (code 'root-committed)
                      (token-id (.ref token 'token-id)) (nonce token-nonce)
                      (before-root (.ref state 'execution-root))
                      (after-root (.ref consumption-receipt 'execution-root))
                      (consumption consumption-receipt) (durability 'strict))))
            (transition next-state receipt)))))))
  )

(def (poo-flow-strict-mediation-result-state result)
  (.ref result 'state))

(def (poo-flow-strict-mediation-result-receipt result)
  (.ref result 'receipt))
