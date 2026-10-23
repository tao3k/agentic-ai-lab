;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: deterministic AC-10 fixture joining qualified owner identities.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/modules/workflow/contracts/organization-bundle
        :agentic-ai-lab/modules/workflow/contracts/organization-bundle-runtime-v0-batch
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token
        :agentic-ai-lab/modules/authorization/providers/cedar/decision
        :agentic-ai-lab/modules/governance/policy/strict-mediation
        :agentic-ai-lab/modules/proof/projections/proof-case-projection
        :agentic-ai-lab/modules/proof/projections/proof-case-vector
        :agentic-ai-lab/modules/proof/projections/generated/proof-case-vector-v1)

;; : (-> Object DigestHex)
(def (fixture-digest value)
  (hex-encode
   (sha256
    (string->utf8
     (call-with-output-string (lambda (port) (write value port)))))))

(def (fixture-bundle)
  (let* ((parent-principal (agentic-ai-lab-organization-principal 'principal-parent))
         (child-principal (agentic-ai-lab-organization-principal 'principal-child))
         (parent-role (agentic-ai-lab-organization-role 'role-parent))
         (child-role (agentic-ai-lab-organization-role 'role-child))
         (parent (agentic-ai-lab-organization-agent
                  'agent-parent 'principal-parent 'role-parent #f
                  '(write search) '(public private)))
         (child (agentic-ai-lab-organization-agent
                 'agent-child 'principal-child 'role-child 'agent-parent
                 '(search) '(public)))
         (search (agentic-ai-lab-organization-capability 'search #t))
         (write (agentic-ai-lab-organization-capability 'write #t))
         (delegation (agentic-ai-lab-organization-delegation
                      'agent-parent 'agent-child 'search))
         (context (agentic-ai-lab-organization-context-projection
                   'agent-child '(public)))
         (effect (agentic-ai-lab-organization-tool-effect
                  'search-tool 'search 'external-tool)))
    (agentic-ai-lab-organization-bundle
     7
     (agentic-ai-lab-organization-organization-facet
      (list parent-principal child-principal parent-role child-role
            parent child))
     (agentic-ai-lab-organization-authority-facet
      (list search write) (list delegation))
     (agentic-ai-lab-organization-context-facet (list context))
     (agentic-ai-lab-organization-protocol-facet (list effect) '())
     (agentic-ai-lab-organization-empty-evidence-facet))))

;; : (-> DigestHex DigestHex DigestHex DigestHex DigestHex DigestHex Epoch AgenticAILabEffectBinding)
(def (fixture-binding bundle-digest policy-digest entity-digest
                      decision-digest intent-digest payload-digest epoch)
  (agentic-ai-lab-effect-binding
   bundle-digest epoch policy-digest entity-digest decision-digest intent-digest
   'attempt-1 'external-tool 'python-runtime 'session-1
   1 1 'arena-1 3 0 16 payload-digest 'lease-1))

(def (fixture-obligations)
  (agentic-ai-lab-authorized-effect-obligations #t #t #t #t #t #t #t #t))

;;; Fixture boundary: derive every linked digest from one deterministic canonical scenario.
(def (agentic-ai-lab-agentic-control-plane-canonical-fixture)
  (let* ((bundle (fixture-bundle))
         (bundle-validation (agentic-ai-lab-organization-bundle-validate bundle))
         (bundle-identity (agentic-ai-lab-organization-bundle-identity bundle))
         (bundle-digest (.ref bundle-identity 'digest))
         (policy-digest (fixture-digest 'cedar-policy-v1))
         (entity-digest (fixture-digest 'cedar-entities-v1))
         (intent-digest (fixture-digest 'search-public-context))
         (payload-digest (fixture-digest 'search-payload))
         (decision (agentic-ai-lab-cedar-decision
                    'decision-1 'permit 'policy-1 policy-digest entity-digest '()))
         (decision-digest (.ref decision 'decision-digest))
         (semantic-root
          (agentic-ai-lab-cedar-decision->semantic-root
           decision bundle-digest intent-digest))
         (binding
          (fixture-binding bundle-digest policy-digest entity-digest
                           decision-digest intent-digest payload-digest 7))
         (validity (agentic-ai-lab-token-validity 10 10 20 4))
         (token
          (agentic-ai-lab-cedar-decision->authorized-effect-token
           decision 'token-1 11 semantic-root binding validity
           'strict 255 'scheme-control "signature"))
         (context
          (agentic-ai-lab-token-validation-context semantic-root binding 15 4 '()))
         (initial-root (fixture-digest 'execution-root-0))
         (mediation
          (agentic-ai-lab-strict-mediate
           (agentic-ai-lab-strict-mediation-state initial-root 0 '() 4)
           token context initial-root (fixture-digest 'runtime-observation)))
         (mediation-receipt
          (agentic-ai-lab-strict-mediation-result-receipt mediation))
         (execution-root (.ref mediation-receipt 'after-root))
         (proof-roots
          (agentic-ai-lab-proof-evidence-roots
           (.ref semantic-root 'digest) execution-root #f))
         (proof-case
          (agentic-ai-lab-authorized-effect-proof-case
           token proof-roots (fixture-obligations)
           'committed 1 'strict 4 initial-root))
         (vector (make-u8vector agentic-ai-lab-proof-case-vector-size 0))
         (_written (agentic-ai-lab-proof-case-vector-write! proof-case vector))
         (vector-digest (agentic-ai-lab-proof-case-vector-digest vector))
         (event
          (agentic-ai-lab-runtime-v0-event
           1 0 1
           (agentic-ai-lab-runtime-v0-compact-id 1 1)
           (agentic-ai-lab-runtime-v0-compact-id 2 1)
           (agentic-ai-lab-runtime-v0-compact-id 3 1)
           0 16 9000 255)))
    (object<-alist
     (list
      (cons 'kind 'agentic-ai-lab.agentic-control-plane.canonical-fixture.v1)
      (cons 'status
            (if (and (agentic-ai-lab-organization-validation-accepted?
                      bundle-validation)
                     (.ref mediation-receipt 'accepted?)
                     (agentic-ai-lab-authorized-effect-proof-case-valid? proof-case))
              'qualified
              'rejected))
      (cons 'bundle bundle)
      (cons 'bundle-validation bundle-validation)
      (cons 'bundle-identity bundle-identity)
      (cons 'runtime-event event)
      (cons 'runtime-native-fields
            (agentic-ai-lab-runtime-v0-event->native-fields event))
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
                        (agentic-ai-lab-authorized-effect-token-digest token))
                  (cons 'effect (agentic-ai-lab-effect-binding-digest binding))
                  (cons 'semantic-root (.ref semantic-root 'digest))
                  (cons 'execution-root execution-root)
                  (cons 'proof-schema agentic-ai-lab-proof-case-schema-fingerprint)
                  (cons 'proof-vector vector-digest)))
      (cons 'required-consumers
            '(runtime-c-installed python-cffi-wheel lean-ffi-smoke))))))

;; : (-> Symbol Symbol AgenticAILabAgenticControlPlaneNegativeFixture)
(def (negative-result kind code)
  (object<-alist
   (map cons
        '(kind mutation accepted? code)
        (list 'agentic-ai-lab.agentic-control-plane.negative-fixture.v1
              kind
              #f
              code))))

;; : (-> AgenticAILabAgenticControlPlaneFixture [AgenticAILabAgenticControlPlaneNegativeFixture])
(def (agentic-ai-lab-agentic-control-plane-negative-fixtures fixture)
  (let* ((token (.ref fixture 'token))
         (binding (.ref token 'binding))
         (root (.ref token 'semantic-root))
         (forbid (agentic-ai-lab-cedar-decision
                  'deny-1 'forbid 'policy-1
                  (.ref binding 'policy-digest)
                  (.ref binding 'entity-digest) '(explicit-deny)))
         (deny-code
          (with-catch
           (lambda (_failure) 'cedar-deny)
           (lambda ()
             (agentic-ai-lab-cedar-decision->authorized-effect-token
              forbid 'denied 12 root binding (.ref token 'validity)
              'strict 255 'scheme-control "signature")
             'unexpected-allow)))
         (replay (.ref (agentic-ai-lab-authorized-effect-token-validate
                        token (agentic-ai-lab-token-validation-context
                               root binding 15 4 '(11)))
                       'code))
         (revocation (.ref (agentic-ai-lab-authorized-effect-token-validate
                            token (agentic-ai-lab-token-validation-context
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
          (.ref (agentic-ai-lab-authorized-effect-token-validate
                 token (agentic-ai-lab-token-validation-context
                        root substitution-binding 15 4 '()))
                'code))
         (vector (.ref fixture 'proof-vector))
         (mutated (u8vector-copy vector))
         (_mutation (u8vector-set! mutated 80
                                   (bitwise-xor #xff (u8vector-ref mutated 80))))
         (expected (cdr (assq 'proof-vector (.ref fixture 'identities))))
         (observed (agentic-ai-lab-proof-case-vector-digest mutated)))
    (list (negative-result 'deny deny-code)
          (negative-result 'replay replay)
          (negative-result 'revocation revocation)
          (negative-result 'binding-substitution substitution)
          (negative-result 'stale-proof
                           (if (equal? expected observed)
                             'unexpected-match 'proof-vector-mismatch)))))
