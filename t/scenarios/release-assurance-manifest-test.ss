;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/workflow/contracts/release-assurance-manifest
        :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/workflow/qualification/capability-prototypes)


(def tcb
  (agentic-ai-lab-assurance-tcb
   'bundle-semantic 'bundle-semantic '(digest validator canonical-schema)))
(def evidence-a
  (agentic-ai-lab-assurance-evidence-reference
   'bundle-receipt 'scheme "receipts/bundle" "digest-a"))
(def evidence-b
  (agentic-ai-lab-assurance-evidence-reference
   'proof-receipt 'lean "receipts/proof" "digest-b"))
(def claim-a
  (agentic-ai-lab-assurance-claim
   'bundle-valid 'l1-conformant 'scheme tcb (list evidence-a)
   '(out-of-band-effects) 'fail-closed))
(def claim-b
  (agentic-ai-lab-assurance-claim
   'proof-linked 'l4-formally-linked 'lean tcb (list evidence-b)
   '(actual-effect-mediation) 'reject-proof))
(def gate-a
  (agentic-ai-lab-assurance-gate-result
   'scheme-owner 'scheme 'passed evidence-a))
(def gate-b
  (agentic-ai-lab-assurance-gate-result
   'lean-owner 'lean 'passed evidence-b))
(def abi (agentic-ai-lab-assurance-abi-decision 'runtime-v0.1 #f 'ac10-review))

(def (manifest claims gates tcbs)
  (agentic-ai-lab-release-assurance-manifest
   'rc-1 "revision-1" 'macos-arm64
   '((gerbil . "0.18.2") (lean . "4"))
   '((bundle . "bundle-digest") (proof-vector . "vector-digest"))
   tcbs claims gates abi))

(def (manifest-local-shell value)
  (list (cons 'kind +agentic-ai-lab-release-assurance-manifest-schema+)
        (cons 'schema +agentic-ai-lab-release-assurance-manifest-schema+)
        (cons 'release (.ref value 'release))
        (cons 'environment (.ref value 'environment))
        (cons 'assurance (.ref value 'assurance))
        (cons 'abi-decision (.ref value 'abi-decision))))

(def (manifest-with-capabilities value schema-id-value schema-version-value
                                 revision-value)
  (poo-core-role-object
   (slots ((kind +agentic-ai-lab-release-assurance-manifest-schema+)
           (schema +agentic-ai-lab-release-assurance-manifest-schema+)
           (release (.ref value 'release))
           (environment (.ref value 'environment))
           (assurance (.ref value 'assurance))
           (abi-decision (.ref value 'abi-decision))))
   (supers
    (agentic-ai-lab-versioned-capability
     schema-id-value schema-version-value)
    (agentic-ai-lab-revision-bound-capability revision-value))))

(def release-assurance-manifest-test
  (test-suite "AC-10 S1 ReleaseAssuranceManifest v1"
    (yuanxu-test-case "POO-native object family and complete manifest validate"
      (let (value (manifest (list claim-a claim-b)
                            (list gate-a gate-b) (list tcb)))
        (let (receipt (agentic-ai-lab-release-assurance-manifest-validate value))
          (check (agentic-ai-lab-release-assurance-manifest? value) => #t)
          (check (agentic-ai-lab-assurance-claim? claim-a) => #t)
          (check (agentic-ai-lab-assurance-tcb? tcb) => #t)
          (check (agentic-ai-lab-assurance-evidence-reference? evidence-a) => #t)
          (check (agentic-ai-lab-assurance-gate-result? gate-a) => #t)
          (check (agentic-ai-lab-assurance-abi-decision? abi) => #t)
          (check (.ref value 'qualification/versioned?) => #t)
          (check (.ref value 'schema-id)
                 => +agentic-ai-lab-release-assurance-manifest-schema+)
          (check (.ref value 'schema-version) => 1)
          (check (.ref value 'qualification/revision-bound?) => #t)
          (check (.ref value 'source-revision) => "revision-1")
          (check (.ref receipt 'accepted?) => #t)
          (check (.ref receipt 'diagnostics) => '()))))
    (yuanxu-test-case "capability instances are isolated"
      (let ((left (manifest (list claim-a) (list gate-a) (list tcb)))
            (right (agentic-ai-lab-release-assurance-manifest
                    'rc-2 "revision-2" 'macos-arm64
                    '((gerbil . "0.18.2"))
                    '((bundle . "bundle-digest"))
                    (list tcb) (list claim-a) (list gate-a) abi)))
        (check (.ref left 'source-revision) => "revision-1")
        (check (.ref right 'source-revision) => "revision-2")
        (check (.ref left 'schema-version) => 1)
        (check (.ref right 'schema-version) => 1)))
    (yuanxu-test-case "missing and divergent capability bindings fail closed"
      (let* ((valid (manifest (list claim-a) (list gate-a) (list tcb)))
             (flat (object<-alist (manifest-local-shell valid)))
             (wrong-schema
              (manifest-with-capabilities
               valid 'agentic-ai-lab.release-assurance-manifest.other 2
               "revision-1"))
             (divergent
              (manifest-with-capabilities
               valid +agentic-ai-lab-release-assurance-manifest-schema+ 1
               "other-revision")))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref (agentic-ai-lab-release-assurance-manifest-validate flat)
                          'diagnostics))
               => '(invalid-capability-composition))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref
                     (agentic-ai-lab-release-assurance-manifest-validate wrong-schema)
                     'diagnostics))
               => '(capability-schema-mismatch))
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref
                     (agentic-ai-lab-release-assurance-manifest-validate divergent)
                     'diagnostics))
               => '(capability-revision-mismatch))))
    (yuanxu-test-case "construction order does not change canonical identity"
      (let* ((left (manifest (list claim-a claim-b)
                             (list gate-a gate-b) (list tcb)))
             (right (agentic-ai-lab-release-assurance-manifest
                     'rc-1 "revision-1" 'macos-arm64
                     '((lean . "4") (gerbil . "0.18.2"))
                     '((proof-vector . "vector-digest")
                       (bundle . "bundle-digest"))
                     (list tcb) (list claim-b claim-a)
                     (list gate-b gate-a) abi)))
        (check (agentic-ai-lab-release-assurance-manifest-normalize left)
               => (agentic-ai-lab-release-assurance-manifest-normalize right))
        (check (.ref (agentic-ai-lab-release-assurance-manifest-identity left) 'digest)
               => (.ref (agentic-ai-lab-release-assurance-manifest-identity right)
                        'digest))
        (check (.ref (agentic-ai-lab-release-assurance-manifest-identity left) 'digest)
               => "871e2303fcabbaffb4b3a95dfbafdef4fb65768ad9a5ae4c75e409b20bd73de5")))
    (yuanxu-test-case "identity changes when bound release evidence changes"
      (let* ((left (manifest (list claim-a) (list gate-a) (list tcb)))
             (changed (agentic-ai-lab-release-assurance-manifest
                       'rc-1 "revision-2" 'macos-arm64
                       '((gerbil . "0.18.2") (lean . "4"))
                       '((bundle . "bundle-digest")
                         (proof-vector . "vector-digest"))
                       (list tcb) (list claim-a) (list gate-a) abi)))
        (check (equal? (.ref (agentic-ai-lab-release-assurance-manifest-identity left)
                             'digest)
                       (.ref (agentic-ai-lab-release-assurance-manifest-identity changed)
                             'digest))
               => #f)))
    (yuanxu-test-case "missing identities, claims, gates, and ABI review fail closed"
      (let* ((invalid-abi (agentic-ai-lab-assurance-abi-decision 'runtime-v0.1 #f ""))
             (value (agentic-ai-lab-release-assurance-manifest
                     'rc-1 "revision-1" 'macos-arm64 '() '()
                     (list tcb) '() '() invalid-abi))
             (receipt (agentic-ai-lab-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(missing-identities invalid-claims invalid-gates
                    invalid-abi-decision))))
    (yuanxu-test-case "duplicate semantic owners are rejected deterministically"
      (let* ((duplicate-tcb
              (agentic-ai-lab-assurance-tcb
               'bundle-semantic 'authorization '(cedar evaluator)))
             (duplicate-claim
              (agentic-ai-lab-assurance-claim
               'bundle-valid 'l2-evidenced 'cedar tcb (list evidence-b)
               '() 'fail-closed))
             (duplicate-gate
              (agentic-ai-lab-assurance-gate-result
               'scheme-owner 'other 'passed evidence-b))
             (value (manifest (list claim-a duplicate-claim)
                              (list gate-a duplicate-gate)
                              (list tcb duplicate-tcb)))
             (receipt (agentic-ai-lab-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(duplicate-tcb-id duplicate-claim-id duplicate-gate-id))))
    (yuanxu-test-case "incomplete claim and invalid evidence reference fail closed"
      (let* ((incomplete
              (agentic-ai-lab-assurance-claim
               'incomplete 'l2-evidenced "" tcb '() '() ""))
             (bad-gate
              (agentic-ai-lab-assurance-gate-result
               'bad 'scheme 'passed (.o (kind 'not-evidence))))
             (value (manifest (list incomplete) (list bad-gate) (list tcb)))
             (receipt (agentic-ai-lab-release-assurance-manifest-validate value)))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(incomplete-claim invalid-gate-result))))))
