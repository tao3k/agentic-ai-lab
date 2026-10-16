;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Scheme POO owns semantic roots and one-shot effect capabilities.
;;; Invariant: validation and consumption are pure immutable transitions.
(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))

(export poo-flow-semantic-root
        poo-flow-effect-binding
        poo-flow-effect-binding-digest
        poo-flow-token-validity
        poo-flow-authorized-effect-token
        poo-flow-authorized-effect-token-digest
        poo-flow-token-validation-context
        poo-flow-authorized-effect-token-validate
        poo-flow-authorized-effect-token-consume)

(def (canonical-digest value)
  (hex-encode
   (sha256
    (string->utf8
     (call-with-output-string (lambda (port) (write value port)))))))

(def (poo-flow-effect-binding-digest binding-object)
  (unless (eq? (.ref binding-object 'kind) 'poo-flow-effect-binding)
    (error "effect binding digest requires EffectBinding" binding-object))
  (canonical-digest
   (cons 'poo-flow.effect-binding.v1
         (binding-projection binding-object))))

(def (poo-flow-authorized-effect-token-digest token-object)
  (unless (eq? (.ref token-object 'kind) 'poo-flow-authorized-effect-token)
    (error "token digest requires AuthorizedEffectToken" token-object))
  (let (validity (.ref token-object 'validity))
    (canonical-digest
     (list 'poo-flow.authorized-effect-token.v1
           (.ref token-object 'token-id)
           (.ref token-object 'nonce)
           (.ref (.ref token-object 'semantic-root) 'digest)
           (poo-flow-effect-binding-digest (.ref token-object 'binding))
           (list (.ref validity 'issued-at)
                 (.ref validity 'not-before)
                 (.ref validity 'expiry)
                 (.ref validity 'revocation-epoch))
           (.ref token-object 'durability)
           (.ref token-object 'required-evidence-bits)
           (.ref token-object 'issuer-id)
           (.ref token-object 'signature)))))

(def (poo-flow-semantic-root b-digest p-digest e-digest d-digest i-digest)
  (let (canonical
        (list 'poo-flow.semantic-root.draft.1 b-digest p-digest
              e-digest d-digest i-digest))
    (.o (kind 'poo-flow-semantic-root)
        (schema 'poo-flow.semantic-root.draft.1)
        (bundle-digest b-digest) (policy-digest p-digest)
        (entity-digest e-digest) (decision-digest d-digest)
        (intent-digest i-digest)
        (digest (canonical-digest canonical)))))

(def (poo-flow-effect-binding b-digest b-epoch p-digest e-digest d-digest i-digest
                              attempt effect runtime session seq-start seq-end
                              arena arena-gen offset length pld-digest lease)
  (object<-alist
   (list (cons 'kind 'poo-flow-effect-binding)
         (cons 'bundle-digest b-digest) (cons 'bundle-epoch b-epoch)
         (cons 'policy-digest p-digest) (cons 'entity-digest e-digest)
         (cons 'decision-digest d-digest) (cons 'intent-digest i-digest)
         (cons 'attempt-id attempt) (cons 'effect-kind effect)
         (cons 'runtime-id runtime) (cons 'session-id session)
         (cons 'sequence-start seq-start) (cons 'sequence-end seq-end)
         (cons 'arena-id arena) (cons 'arena-generation arena-gen)
         (cons 'payload-offset offset) (cons 'payload-length length)
         (cons 'payload-digest pld-digest) (cons 'lease-id lease))))

(def (poo-flow-token-validity issued not-before-time expiry-time revocation)
  (.o (kind 'poo-flow-token-validity)
      (issued-at issued) (not-before not-before-time) (expiry expiry-time)
      (revocation-epoch revocation)))

(def (poo-flow-authorized-effect-token identity token-nonce root effect-binding
                                       token-validity profile evidence-bits
                                       issuer token-signature)
  (object<-alist
   (list (cons 'kind 'poo-flow-authorized-effect-token)
         (cons 'schema 'poo-flow.authorized-effect-token.draft.1)
         (cons 'token-id identity) (cons 'nonce token-nonce)
         (cons 'semantic-root root) (cons 'binding effect-binding)
         (cons 'validity token-validity) (cons 'durability profile)
         (cons 'required-evidence-bits evidence-bits)
         (cons 'issuer-id issuer) (cons 'signature token-signature))))

(def (poo-flow-token-validation-context root expected-binding current-time
                                         current-revocation spent-nonces)
  (.o (kind 'poo-flow-token-validation-context)
      (semantic-root root) (binding expected-binding) (now current-time)
      (revocation-epoch current-revocation) (consumed-nonces spent-nonces)))

(def (binding-projection binding)
  (list (.ref binding 'bundle-digest) (.ref binding 'bundle-epoch)
        (.ref binding 'policy-digest) (.ref binding 'entity-digest)
        (.ref binding 'decision-digest) (.ref binding 'intent-digest)
        (.ref binding 'attempt-id) (.ref binding 'effect-kind)
        (.ref binding 'runtime-id) (.ref binding 'session-id)
        (.ref binding 'sequence-start) (.ref binding 'sequence-end)
        (.ref binding 'arena-id) (.ref binding 'arena-generation)
        (.ref binding 'payload-offset) (.ref binding 'payload-length)
        (.ref binding 'payload-digest) (.ref binding 'lease-id)))

(def (binding-equal? left right)
  (equal? (binding-projection left) (binding-projection right)))

(def (rejection-code token context)
  (let ((validity (.ref token 'validity))
        (nonce (.ref token 'nonce)))
    (cond
     ((not (equal? (.ref (.ref token 'semantic-root) 'digest)
                   (.ref (.ref context 'semantic-root) 'digest)))
      'semantic-root-mismatch)
     ((not (binding-equal? (.ref token 'binding) (.ref context 'binding)))
      'binding-substitution)
     ((member nonce (.ref context 'consumed-nonces)) 'token-reuse)
     ((< (.ref context 'now) (.ref validity 'not-before)) 'token-not-yet-valid)
     ((> (.ref context 'now) (.ref validity 'expiry)) 'token-expired)
     ((not (= (.ref validity 'revocation-epoch)
              (.ref context 'revocation-epoch))) 'stale-revocation-epoch)
     ((eq? (.ref token 'durability) 'diagnostic) 'diagnostic-cannot-execute)
     (else #f))))

(def (poo-flow-authorized-effect-token-validate token context)
  (let (rejection (rejection-code token context))
    (.o (kind 'poo-flow-token-validation-receipt)
        (accepted? (not rejection)) (code (or rejection 'token-reserved))
        (token-id (.ref token 'token-id)) (nonce (.ref token 'nonce))
        (semantic-root (.ref token 'semantic-root))
        (binding (.ref token 'binding))
        (durability (.ref token 'durability)))))

(def (poo-flow-authorized-effect-token-consume token validation
                                               prior-root observation)
  (unless (.ref validation 'accepted?)
    (error "cannot consume rejected AuthorizedEffectToken"))
  (let* ((leaf (list 'poo-flow.execution-leaf.draft.1
                     prior-root (.ref token 'nonce)
                     (.ref (.ref token 'semantic-root) 'digest)
                     observation))
         (next-root (canonical-digest leaf)))
    (.o (kind 'poo-flow-token-consumption-receipt)
        (outcome 'committed) (token-id (.ref token 'token-id))
        (nonce (.ref token 'nonce))
        (semantic-root (.ref token 'semantic-root))
        (previous-execution-root prior-root)
        (observation-digest observation)
        (execution-root next-root)
        (durability (.ref token 'durability)))))
