;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/contracts/release-assurance-manifest
        :core/object-family/role-syntax
        :poo-flow/modules/workflow/qualification/capability-prototypes)


(def tcb
  (poo-flow-assurance-tcb
   'bundle-semantic 'bundle-semantic '(digest validator canonical-schema)))
(def evidence-a
  (poo-flow-assurance-evidence-reference
   'bundle-receipt 'scheme "receipts/bundle" "digest-a"))
(def evidence-b
  (poo-flow-assurance-evidence-reference
   'proof-receipt 'lean "receipts/proof" "digest-b"))
(def claim-a
  (poo-flow-assurance-claim
   'bundle-valid 'l1-conformant 'scheme tcb (list evidence-a)
   '(out-of-band-effects) 'fail-closed))
(def claim-b
  (poo-flow-assurance-claim
   'proof-linked 'l4-formally-linked 'lean tcb (list evidence-b)
   '(actual-effect-mediation) 'reject-proof))
(def gate-a
  (poo-flow-assurance-gate-result
   'scheme-owner 'scheme 'passed evidence-a))
(def gate-b
  (poo-flow-assurance-gate-result
   'lean-owner 'lean 'passed evidence-b))
(def abi (poo-flow-assurance-abi-decision 'runtime-v0.1 #f 'ac10-review))

(def (manifest claims gates tcbs)
  (poo-flow-release-assurance-manifest
   'rc-1 "revision-1" 'macos-arm64
   '((gerbil . "0.18.2") (lean . "4"))
   '((bundle . "bundle-digest") (proof-vector . "vector-digest"))
   tcbs claims gates abi))

(def (manifest-local-shell value)
  (list (cons 'kind +poo-flow-release-assurance-manifest-schema+)
        (cons 'schema +poo-flow-release-assurance-manifest-schema+)
        (cons 'release (.ref value 'release))
        (cons 'environment (.ref value 'environment))
        (cons 'assurance (.ref value 'assurance))
        (cons 'abi-decision (.ref value 'abi-decision))))

(def (manifest-with-capabilities value schema-id-value schema-version-value
                                 revision-value)
  (poo-core-role-object
   (slots ((kind +poo-flow-release-assurance-manifest-schema+)
           (schema +poo-flow-release-assurance-manifest-schema+)
           (release (.ref value 'release))
           (environment (.ref value 'environment))
           (assurance (.ref value 'assurance))
           (abi-decision (.ref value 'abi-decision))))
   (supers
    (poo-flow-versioned-capability
     schema-id-value schema-version-value)
    (poo-flow-revision-bound-capability revision-value))))

(def release-assurance-manifest-test
  (test-suite "AC-10 S1 ReleaseAssuranceManifest v1"
    (poo-flow-test-case "POO-native object family and complete manifest validate"
      (let (value (manifest (list claim-a claim-b)
                            (list gate-a gate-b) (list tcb)))
        (let (receipt (poo-flow-release-assurance-manifest-validate value))
          (check (poo-flow-release-assurance-manifest? value) => #t)
          (check (poo-flow-assurance-claim? claim-a) => #t)
          (check (poo-flow-assurance-tcb? tcb) => #t)
          (check (poo-flow-assurance-evidence-reference? evidence-a) => #t)
          (check (poo-flow-assurance-gate-result? gate-a) => #t)
          (check (poo-flow-assurance-abi-decision? abi) => #t)
          (check (.ref value 'qualification/versioned?) => #t)
          (check (.ref value 'schema-id)
                 => +poo-flow-release-assurance-manifest-schema+)
          (check (.ref value 'schema-version) => 1)
          (check (.ref value 'qualification/revision-bound?) => #t)
          (check (.ref value 'source-revision) => "revision-1")
          (check (.ref receipt 'accepted?) => #t)
          (check (.ref receipt 'diagnostics) => '()))))
    (poo-flow-test-case "capability instances are isolated"
      (let ((left (manifest (list claim-a) (list gate-a) (list tcb)))
            (right (poo-flow-release-assurance-manifest
                    'rc-2 "revision-2" 'macos-arm64
                    '((gerbil . "0.18.2"))
                    '((bundle . "bundle-digest"))
                    (list tcb) (list claim-a) (list gate-a) abi)))
        (check (.ref left 'source-revision) => "revision-1")
        (check (.ref right 'source-revision) => "revision-2")
        (check (.ref left 'schema-version) => 1)
        (check (.ref right 'schema-version) => 1)))
    (poo-flow-test-case "missing and divergent capability bindings fail closed"
      (let* ((valid (manifest (list claim-a) (list gate-a) (list tcb)))
             (flat (object<-alist (manifest-local-shell valid)))
             (wrong-schema
              (manifest-with-capabilities
               valid 'poo-flow.release-assurance-manifest.other 2
               "revision-1"))
             (divergent
              (manifest-with-capabilities
               valid +poo-flow-release-assurance-manifest-schema+ 1
               "other-revision")))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref (poo-flow-release-assurance-manifest-validate flat)
                          'diagnostics))
               => '(invalid-capability-composition))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref
                     (poo-flow-release-assurance-manifest-validate wrong-schema)
                     'diagnostics))
               => '(capability-schema-mismatch))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref
                     (poo-flow-release-assurance-manifest-validate divergent)
                     'diagnostics))
               => '(capability-revision-mismatch))))
    (poo-flow-test-case "construction order does not change canonical identity"
      (let* ((left (manifest (list claim-a claim-b)
                             (list gate-a gate-b) (list tcb)))
             (right (poo-flow-release-assurance-manifest
                     'rc-1 "revision-1" 'macos-arm64
                     '((lean . "4") (gerbil . "0.18.2"))
                     '((proof-vector . "vector-digest")
                       (bundle . "bundle-digest"))
                     (list tcb) (list claim-b claim-a)
                     (list gate-b gate-a) abi)))
        (check (poo-flow-release-assurance-manifest-normalize left)
               => (poo-flow-release-assurance-manifest-normalize right))
        (check (.ref (poo-flow-release-assurance-manifest-identity left) 'digest)
               => (.ref (poo-flow-release-assurance-manifest-identity right)
                        'digest))
        (check (.ref (poo-flow-release-assurance-manifest-identity left) 'digest)
               => "871e2303fcabbaffb4b3a95dfbafdef4fb65768ad9a5ae4c75e409b20bd73de5")))
    (poo-flow-test-case "identity changes when bound release evidence changes"
      (let* ((left (manifest (list claim-a) (list gate-a) (list tcb)))
             (changed (poo-flow-release-assurance-manifest
                       'rc-1 "revision-2" 'macos-arm64
                       '((gerbil . "0.18.2") (lean . "4"))
                       '((bundle . "bundle-digest")
                         (proof-vector . "vector-digest"))
                       (list tcb) (list claim-a) (list gate-a) abi)))
        (check (equal? (.ref (poo-flow-release-assurance-manifest-identity left)
                             'digest)
                       (.ref (poo-flow-release-assurance-manifest-identity changed)
                             'digest))
               => #f)))
    (poo-flow-test-case "missing identities, claims, gates, and ABI review fail closed"
      (let* ((invalid-abi (poo-flow-assurance-abi-decision 'runtime-v0.1 #f ""))
             (value (poo-flow-release-assurance-manifest
                     'rc-1 "revision-1" 'macos-arm64 '() '()
                     (list tcb) '() '() invalid-abi))
             (receipt (poo-flow-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(missing-identities invalid-claims invalid-gates
                    invalid-abi-decision))))
    (poo-flow-test-case "duplicate semantic owners are rejected deterministically"
      (let* ((duplicate-tcb
              (poo-flow-assurance-tcb
               'bundle-semantic 'authorization '(cedar evaluator)))
             (duplicate-claim
              (poo-flow-assurance-claim
               'bundle-valid 'l2-evidenced 'cedar tcb (list evidence-b)
               '() 'fail-closed))
             (duplicate-gate
              (poo-flow-assurance-gate-result
               'scheme-owner 'other 'passed evidence-b))
             (value (manifest (list claim-a duplicate-claim)
                              (list gate-a duplicate-gate)
                              (list tcb duplicate-tcb)))
             (receipt (poo-flow-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(duplicate-tcb-id duplicate-claim-id duplicate-gate-id))))
    (poo-flow-test-case "incomplete claim and invalid evidence reference fail closed"
      (let* ((incomplete
              (poo-flow-assurance-claim
               'incomplete 'l2-evidenced "" tcb '() '() ""))
             (bad-gate
              (poo-flow-assurance-gate-result
               'bad 'scheme 'passed (.o (kind 'not-evidence))))
             (value (manifest (list incomplete) (list bad-gate) (list tcb)))
             (receipt (poo-flow-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(incomplete-claim invalid-gate-result))))))
