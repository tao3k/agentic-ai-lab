;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: deterministic AC-10 fixture joining qualified owner identities.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        :poo-flow/modules/query/semantic/organization-bundle
        :poo-flow/modules/workflow/contracts/organization-bundle
        :poo-flow/modules/workflow/contracts/organization-bundle-runtime-v0-batch
        :poo-flow/modules/governance/policy/authorized-effect-token
        :poo-flow/modules/authorization/providers/cedar/decision
        :poo-flow/modules/governance/policy/strict-mediation
        :poo-flow/modules/proof/projections/proof-case-projection
        :poo-flow/modules/proof/projections/proof-case-vector
        :poo-flow/modules/proof/projections/generated/proof-case-vector-v1)

;; : (-> Object DigestHex)
(def (fixture-digest value)
  (hex-encode
   (sha256
    (string->utf8
     (call-with-output-string (lambda (port) (write value port)))))))

(def (fixture-bundle)
  (let* ((parent-principal (poo-flow-organization-principal 'principal-parent))
         (child-principal (poo-flow-organization-principal 'principal-child))
         (parent-role (poo-flow-organization-role 'role-parent))
         (child-role (poo-flow-organization-role 'role-child))
         (parent (poo-flow-organization-agent
                  'agent-parent 'principal-parent 'role-parent #f
                  '(write search) '(public private)))
         (child (poo-flow-organization-agent
                 'agent-child 'principal-child 'role-child 'agent-parent
                 '(search) '(public)))
         (search (poo-flow-organization-capability 'search #t))
         (write (poo-flow-organization-capability 'write #t))
         (delegation (poo-flow-organization-delegation
                      'agent-parent 'agent-child 'search))
         (context (poo-flow-organization-context-projection
                   'agent-child '(public)))
         (effect (poo-flow-organization-tool-effect
                  'search-tool 'search 'external-tool)))
    (poo-flow-organization-bundle
     7
     (poo-flow-organization-organization-facet
      (list parent-principal child-principal parent-role child-role
            parent child))
     (poo-flow-organization-authority-facet
      (list search write) (list delegation))
     (poo-flow-organization-context-facet (list context))
     (poo-flow-organization-protocol-facet (list effect) '())
     (poo-flow-organization-empty-evidence-facet))))

;; : (-> DigestHex DigestHex DigestHex DigestHex DigestHex DigestHex Epoch PooFlowEffectBinding)
(def (fixture-binding bundle-digest policy-digest entity-digest
                      decision-digest intent-digest payload-digest epoch)
  (poo-flow-effect-binding
   bundle-digest epoch policy-digest entity-digest decision-digest intent-digest
   'attempt-1 'external-tool 'python-runtime 'session-1
   1 1 'arena-1 3 0 16 payload-digest 'lease-1))

(def (fixture-obligations)
  (poo-flow-authorized-effect-obligations #t #t #t #t #t #t #t #t))

;;; Fixture boundary: derive every linked digest from one deterministic canonical scenario.
(def (poo-flow-agentic-control-plane-canonical-fixture)
  (let* ((bundle (fixture-bundle))
         (bundle-validation (poo-flow-organization-bundle-validate bundle))
         (bundle-identity (poo-flow-organization-bundle-identity bundle))
         (bundle-digest (.ref bundle-identity 'digest))
         (policy-digest (fixture-digest 'cedar-policy-v1))
         (entity-digest (fixture-digest 'cedar-entities-v1))
         (intent-digest (fixture-digest 'search-public-context))
         (payload-digest (fixture-digest 'search-payload))
         (decision (poo-flow-cedar-decision
                    'decision-1 'permit 'policy-1 policy-digest entity-digest '()))
         (decision-digest (.ref decision 'decision-digest))
         (semantic-root
          (poo-flow-cedar-decision->semantic-root
           decision bundle-digest intent-digest))
         (binding
          (fixture-binding bundle-digest policy-digest entity-digest
                           decision-digest intent-digest payload-digest 7))
         (validity (poo-flow-token-validity 10 10 20 4))
         (token
          (poo-flow-cedar-decision->authorized-effect-token
           decision 'token-1 11 semantic-root binding validity
           'strict 255 'scheme-control "signature"))
         (context
          (poo-flow-token-validation-context semantic-root binding 15 4 '()))
         (initial-root (fixture-digest 'execution-root-0))
         (mediation
          (poo-flow-strict-mediate
           (poo-flow-strict-mediation-state initial-root 0 '() 4)
           token context initial-root (fixture-digest 'runtime-observation)))
         (mediation-receipt
          (poo-flow-strict-mediation-result-receipt mediation))
         (execution-root (.ref mediation-receipt 'after-root))
         (proof-roots
          (poo-flow-proof-evidence-roots
           (.ref semantic-root 'digest) execution-root #f))
         (proof-case
          (poo-flow-authorized-effect-proof-case
           token proof-roots (fixture-obligations)
           'committed 1 'strict 4 initial-root))
         (vector (make-u8vector poo-flow-proof-case-vector-size 0))
         (_written (poo-flow-proof-case-vector-write! proof-case vector))
         (vector-digest (poo-flow-proof-case-vector-digest vector))
         (event
          (poo-flow-runtime-v0-event
           1 0 1
           (poo-flow-runtime-v0-compact-id 1 1)
           (poo-flow-runtime-v0-compact-id 2 1)
           (poo-flow-runtime-v0-compact-id 3 1)
           0 16 9000 255)))
    (object<-alist
     (list
      (cons 'kind 'poo-flow.agentic-control-plane.canonical-fixture.v1)
      (cons 'status
            (if (and (poo-flow-organization-validation-accepted?
                      bundle-validation)
                     (.ref mediation-receipt 'accepted?)
                     (poo-flow-authorized-effect-proof-case-valid? proof-case))
              'qualified
              'rejected))
      (cons 'bundle bundle)
      (cons 'bundle-validation bundle-validation)
      (cons 'bundle-identity bundle-identity)
      (cons 'runtime-event event)
      (cons 'runtime-native-fields
            (poo-flow-runtime-v0-event->native-fields event))
      (cons 'cedar-decision decision)
      (cons 'token token)
      (cons 'mediation-receipt mediation-receipt)
      (cons 'proof-case proof-case)
      (cons 'proof-vector vector)
      (cons 'identities
            (list (cons 'bundle bundle-digest)
                  (cons 'policy policy-digest)
                  (cons 'entities entity-digest)
                  (cons 'decision decision-digest)
                  (cons 'token
                        (poo-flow-authorized-effect-token-digest token))
                  (cons 'effect (poo-flow-effect-binding-digest binding))
                  (cons 'semantic-root (.ref semantic-root 'digest))
                  (cons 'execution-root execution-root)
                  (cons 'proof-schema poo-flow-proof-case-schema-fingerprint)
                  (cons 'proof-vector vector-digest)))
      (cons 'required-consumers
            '(runtime-c-installed python-cffi-wheel lean-ffi-smoke))))))

;; : (-> Symbol Symbol PooFlowAgenticControlPlaneNegativeFixture)
(def (negative-result kind code)
  (object<-alist
   (map cons
        '(kind mutation accepted? code)
        (list 'poo-flow.agentic-control-plane.negative-fixture.v1
              kind
              #f
              code))))

;; : (-> PooFlowAgenticControlPlaneFixture [PooFlowAgenticControlPlaneNegativeFixture])
(def (poo-flow-agentic-control-plane-negative-fixtures fixture)
  (let* ((token (.ref fixture 'token))
         (binding (.ref token 'binding))
         (root (.ref token 'semantic-root))
         (forbid (poo-flow-cedar-decision
                  'deny-1 'forbid 'policy-1
                  (.ref binding 'policy-digest)
                  (.ref binding 'entity-digest) '(explicit-deny)))
         (deny-code
          (with-catch
           (lambda (_failure) 'cedar-deny)
           (lambda ()
             (poo-flow-cedar-decision->authorized-effect-token
              forbid 'denied 12 root binding (.ref token 'validity)
              'strict 255 'scheme-control "signature")
             'unexpected-allow)))
         (replay (.ref (poo-flow-authorized-effect-token-validate
                        token (poo-flow-token-validation-context
                               root binding 15 4 '(11)))
                       'code))
         (revocation (.ref (poo-flow-authorized-effect-token-validate
                            token (poo-flow-token-validation-context
                                   root binding 15 5 '()))
                           'code))
         (substitution-binding
          (fixture-binding (.ref binding 'bundle-digest)
                           (.ref binding 'policy-digest)
                           (.ref binding 'entity-digest)
                           (.ref binding 'decision-digest)
                           (.ref binding 'intent-digest)
                           (.ref binding 'payload-digest) 8))
         (substitution
          (.ref (poo-flow-authorized-effect-token-validate
                 token (poo-flow-token-validation-context
                        root substitution-binding 15 4 '()))
                'code))
         (vector (.ref fixture 'proof-vector))
         (mutated (u8vector-copy vector))
         (_mutation (u8vector-set! mutated 80
                                   (bitwise-xor #xff (u8vector-ref mutated 80))))
         (expected (cdr (assq 'proof-vector (.ref fixture 'identities))))
         (observed (poo-flow-proof-case-vector-digest mutated)))
    (list (negative-result 'deny deny-code)
          (negative-result 'replay replay)
          (negative-result 'revocation revocation)
          (negative-result 'binding-substitution substitution)
          (negative-result 'stale-proof
                           (if (equal? expected observed)
                             'unexpected-match 'proof-vector-mismatch)))))
