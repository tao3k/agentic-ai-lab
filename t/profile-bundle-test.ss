;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .all-slots .o .ref .slot?)
        (only-in :core/observability/slot-presentation
                 poo-flow-slot-presentation)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        :core/profile-composition/profile-bundle
        (only-in :poo-flow/modules/workflow/scenario/profile-root
                 poo-flow-profile-bundle-root))

(export profile-bundle-test)

(def audit-profile
  (.o identity: 'audit
      name: 'audit
      stages: (.o)
      runtime-executed?: #f))

(def governed-profile
  (.o identity: 'governed
      name: 'governed
      stages: (.o)
      runtime-executed?: #f))

(def string-identity-profile
  (.o identity: "example/profile"
      name: 'example-profile
      stages: (.o)
      runtime-executed?: #f))

(def module-profiles
  (poo-flow-module-profiles
   (poo-flow-profile-export
    'audit audit-profile
    dependency-roots: '(observability)
    capability-requirements: '(read-receipts)
    revision: 'r1
    generation: 'g1
    provenance: 'test/audit)
   (poo-flow-profile-export
    'governed governed-profile
    dependency-roots: '(governance)
    capability-requirements: '(evaluate-policy)
    revision: 'r1
    generation: 'g1
    provenance: 'test/governed)))

(def test-module
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'assurance)
   profiles: module-profiles))

(def profile-bundle-test
  (test-suite
   "POO-native ProfileBundle algebra"
   (poo-flow-test-case "Module selection uses an indexed export surface"
     (let (bundle
           (poo-flow-select-module-profiles
            test-module 'assurance '(audit governed)))
       (check-equal? (poo-flow-profile-bundle? bundle) #t)
       (check-equal? (.ref bundle 'profiles)
                     (list audit-profile governed-profile))
       (check-equal? (.ref bundle 'profile-identities) '(audit governed))
       (check-equal? (.ref bundle 'imports)
                     '(observability governance))
       (check-equal? (.ref bundle 'capabilities)
                     '(read-receipts evaluate-policy))
       (check-equal? (length (.ref bundle 'selection-proofs)) 2)
       (check-equal? (.ref bundle 'runtime-executed?) #f)))
   (poo-flow-test-case "selection fails closed for an unexported Profile"
     (check-exception
      (poo-flow-select-module-profiles
       test-module 'assurance '(missing))
      true))
   (poo-flow-test-case "direct Profile conflict has ordinary and advanced explanations"
     (let* ((first
             (.o identity: 'clinical-safety
                 provenance: (.o source-path: "t/profile-bundle-test.ss"
                                 source-line: 81)))
            (second
             (.o identity: 'clinical-safety
                 provenance: (.o source-path: "t/profile-bundle-test.ss"
                                 source-line: 84)))
            (failure
             (with-catch values
               (lambda () (compose profiles first second) #f)))
            (ordinary
             (poo-flow-profile-composition-conflict-presentation failure))
            (advanced
             (poo-flow-profile-composition-conflict-presentation
              failure 'advanced)))
       (check-equal? (PooFlowProfileCompositionConflict? failure) #t)
       (check-equal? (.ref ordinary 'identity) 'clinical-safety)
       (check-equal? (.ref ordinary 'reason) 'distinct-direct-values)
       (check-equal? (.ref ordinary 'constraint)
                     'one-profile-value-per-identity)
       (check-equal? (.ref (.ref ordinary 'previous-source) 'source-path)
                     "t/profile-bundle-test.ss")
       (check-equal? (.ref (.ref ordinary 'candidate-source) 'source-line) 84)
       (check-equal? (.slot? ordinary 'previous-value) #f)
       (check-equal? (eq? (.ref advanced 'previous-value) first) #t)
       (check-equal? (eq? (.ref advanced 'candidate-value) second) #t)))
   (poo-flow-test-case "a domain profile-export slot is not a selection proof"
     (let* ((first
             (.o identity: 'clinical-safety
                 profile-export: 'domain-value))
            (second
             (.o identity: 'clinical-safety
                 profile-export: (.o domain-value: #t)))
            (failure
             (with-catch values
               (lambda () (compose profiles first second) #f)))
            (ordinary
             (poo-flow-profile-composition-conflict-presentation failure)))
       (check-equal? (PooFlowProfileCompositionConflict? failure) #t)
       (check-equal? (.ref ordinary 'reason) 'distinct-direct-values)
       (check-equal? (.ref (.ref ordinary 'previous-source) 'status)
                     'undeclared)
       (check-equal? (.ref (.ref ordinary 'candidate-source) 'status)
                     'undeclared)))
   (poo-flow-test-case "selected Profile revision conflict names both constraints"
     (let* ((other-module
             (poo-flow-semantic-module
              (poo-flow-semantic-identity 'test 'assurance)
              profiles:
              (poo-flow-module-profiles
               (poo-flow-profile-export
                'audit audit-profile
                revision: 'r2
                generation: 'g1
                provenance: (.o source-path: "t/profile-bundle-test.ss"
                                source-line: 104)))))
            (first (poo-flow-select-module-profiles
                    test-module 'assurance '(audit)))
            (second (poo-flow-select-module-profiles
                     other-module 'assurance '(audit)))
            (failure
             (with-catch values
               (lambda () (compose profiles first second) #f)))
            (ordinary
             (poo-flow-profile-composition-conflict-presentation failure)))
       (check-equal? (.ref ordinary 'identity) 'audit)
       (check-equal? (.ref ordinary 'reason) 'selection-revision)
       (check-equal? (.ref (.ref ordinary 'constraint) 'previous-revision) 'r1)
       (check-equal? (.ref (.ref ordinary 'constraint) 'candidate-revision) 'r2)
       (check-equal? (.ref (.ref ordinary 'previous-source) 'status)
                     'undeclared)
       (check-equal? (.ref (.ref ordinary 'candidate-source) 'source-line) 104)))
   (poo-flow-test-case "profiles composition is idempotent for one Module instance"
     (let* ((selected
             (poo-flow-select-module-profiles
              test-module 'assurance '(audit governed)))
            (composed (compose profiles selected selected)))
       (check-equal? (.ref composed 'profile-identities) '(audit governed))
       (check-equal? (length (.ref composed 'selection-proofs)) 2)
       (check-equal? (length (.ref composed 'module-bindings)) 1)
       (check-equal? (.ref composed 'imports)
                     '(observability governance))
       (check-equal? (.ref composed 'capabilities)
                     '(read-receipts evaluate-policy))
       (check-equal? (.ref composed 'runtime-executed?) #f)))
   (poo-flow-test-case "explicit Module instances remain distinct"
     (let* ((primary
             (poo-flow-select-module-profiles
              test-module 'primary '(audit)))
            (secondary
             (poo-flow-select-module-profiles
              test-module 'secondary '(audit)))
            (composed (compose profiles primary secondary)))
       (check-equal? (.ref composed 'profile-identities) '(audit audit))
       (check-equal?
        (map (lambda (proof) (.ref proof 'module-instance))
             (.ref composed 'selection-proofs))
        '(primary secondary))))
   (poo-flow-test-case "root projection happens exactly after value composition"
     (let* ((bundle (compose profiles audit-profile governed-profile))
            (root (poo-flow-profile-bundle-root 'assurance-root bundle)))
       (check-equal? (.ref root 'name) 'assurance-root)
       (check-equal? (.ref root 'profiles)
                     (list audit-profile governed-profile))
       (check-equal? (eq? (.ref root 'profile-bundle) bundle) #t)
       (check-equal? (.ref root 'runtime-executed?) #f)))
   (poo-flow-test-case "domain string identities remain valid direct Profile keys"
     (let (bundle (compose profiles string-identity-profile))
       (check-equal? (.ref bundle 'profile-identities)
                     '(example/profile))))
   (poo-flow-test-case "closed Scenario Case presents one effective Stage first"
     (let* ((base-stages (.o triage: 'human-review))
            (refined-stages (.o triage: 'clinician-review
                                audit: 'retain-evidence))
            (base-profile
             (.o identity: 'base-stage-profile stages: base-stages))
            (refined-profile
             (.o identity: 'refined-stage-profile stages: refined-stages))
            (bundle (compose profiles base-profile refined-profile))
            (case-value (poo-flow-profile-bundle-root 'clinical-case bundle))
            (effective-stages (.ref case-value 'stages))
            (sources
             (.o effective: (.o prototype: effective-stages
                                source-path: "core/profile-composition/profile-bundle.ss"
                                source-line: 236)
                 base: (.o prototype: base-stages
                           source-path: "t/profile-bundle-test.ss"
                           source-line: 119)
                 refined: (.o prototype: refined-stages
                              source-path: "t/profile-bundle-test.ss"
                              source-line: 120)))
            (ordinary
             (poo-flow-slot-presentation effective-stages 'triage))
            (detailed
             (poo-flow-slot-presentation
              effective-stages 'triage 'source sources)))
       (check-equal? (.all-slots ordinary) '(effective-value))
       (check-equal? (.ref ordinary 'effective-value) 'human-review)
       (check-equal? (.ref detailed 'declaration-lineage)
                     '(base refined))
       (check-equal?
        (map (lambda (step) (.ref step 'mode))
             (.ref detailed 'composition-chain))
        '(replacement replacement))
       (check-equal? (map (lambda (entry) (.ref entry 'label))
                          (.ref detailed 'prototype-precedence))
                     '(effective base refined))
       (check-equal? (.ref (car (.ref detailed 'source-declarations))
                           'source-line)
                     119)))))
