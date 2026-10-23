;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .all-slots .o .ref .slot?)
        (only-in :yuanxu/observability/slot-presentation
                 yuanxu-slot-presentation)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles yuanxu-semantic-module)
        :yuanxu/profile-composition/profile-bundle
        (only-in :agentic-ai-lab/modules/workflow/scenario/profile-root
                 agentic-ai-lab-profile-bundle-root))

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
  (yuanxu-module-profiles
   (yuanxu-profile-export
    'audit audit-profile
    dependency-roots: '(observability)
    capability-requirements: '(read-receipts)
    revision: 'r1
    generation: 'g1
    provenance: 'test/audit)
   (yuanxu-profile-export
    'governed governed-profile
    dependency-roots: '(governance)
    capability-requirements: '(evaluate-policy)
    revision: 'r1
    generation: 'g1
    provenance: 'test/governed)))

(def test-module
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'assurance)
   profiles: module-profiles))

(def profile-bundle-test
  (test-suite
   "POO-native ProfileBundle algebra"
   (yuanxu-test-case "Module selection uses an indexed export surface"
     (let (bundle
           (yuanxu-select-module-profiles
            test-module 'assurance '(audit governed)))
       (check-equal? (yuanxu-profile-bundle? bundle) #t)
       (check-equal? (.ref bundle 'profiles)
                     (list audit-profile governed-profile))
       (check-equal? (.ref bundle 'profile-identities) '(audit governed))
       (check-equal? (.ref bundle 'imports)
                     '(observability governance))
       (check-equal? (.ref bundle 'capabilities)
                     '(read-receipts evaluate-policy))
       (check-equal? (length (.ref bundle 'selection-proofs)) 2)
       (check-equal? (.ref bundle 'runtime-executed?) #f)))
   (yuanxu-test-case "selection fails closed for an unexported Profile"
     (check-exception
      (yuanxu-select-module-profiles
       test-module 'assurance '(missing))
      true))
   (yuanxu-test-case "direct Profile conflict has ordinary and advanced explanations"
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
             (yuanxu-profile-composition-conflict-presentation failure))
            (advanced
             (yuanxu-profile-composition-conflict-presentation
              failure 'advanced)))
       (check-equal? (YuanxuProfileCompositionConflict? failure) #t)
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
   (yuanxu-test-case "a domain profile-export slot is not a selection proof"
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
             (yuanxu-profile-composition-conflict-presentation failure)))
       (check-equal? (YuanxuProfileCompositionConflict? failure) #t)
       (check-equal? (.ref ordinary 'reason) 'distinct-direct-values)
       (check-equal? (.ref (.ref ordinary 'previous-source) 'status)
                     'undeclared)
       (check-equal? (.ref (.ref ordinary 'candidate-source) 'status)
                     'undeclared)))
   (yuanxu-test-case "selected Profile revision conflict names both constraints"
     (let* ((other-module
             (yuanxu-semantic-module
              (yuanxu-semantic-identity 'test 'assurance)
              profiles:
              (yuanxu-module-profiles
               (yuanxu-profile-export
                'audit audit-profile
                revision: 'r2
                generation: 'g1
                provenance: (.o source-path: "t/profile-bundle-test.ss"
                                source-line: 104)))))
            (first (yuanxu-select-module-profiles
                    test-module 'assurance '(audit)))
            (second (yuanxu-select-module-profiles
                     other-module 'assurance '(audit)))
            (failure
             (with-catch values
               (lambda () (compose profiles first second) #f)))
            (ordinary
             (yuanxu-profile-composition-conflict-presentation failure)))
       (check-equal? (.ref ordinary 'identity) 'audit)
       (check-equal? (.ref ordinary 'reason) 'selection-revision)
       (check-equal? (.ref (.ref ordinary 'constraint) 'previous-revision) 'r1)
       (check-equal? (.ref (.ref ordinary 'constraint) 'candidate-revision) 'r2)
       (check-equal? (.ref (.ref ordinary 'previous-source) 'status)
                     'undeclared)
       (check-equal? (.ref (.ref ordinary 'candidate-source) 'source-line) 104)))
   (yuanxu-test-case "profiles composition is idempotent for one Module instance"
     (let* ((selected
             (yuanxu-select-module-profiles
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
   (yuanxu-test-case "explicit Module instances remain distinct"
     (let* ((primary
             (yuanxu-select-module-profiles
              test-module 'primary '(audit)))
            (secondary
             (yuanxu-select-module-profiles
              test-module 'secondary '(audit)))
            (composed (compose profiles primary secondary)))
       (check-equal? (.ref composed 'profile-identities) '(audit audit))
       (check-equal?
        (map (lambda (proof) (.ref proof 'module-instance))
             (.ref composed 'selection-proofs))
        '(primary secondary))))
   (yuanxu-test-case "root projection happens exactly after value composition"
     (let* ((bundle (compose profiles audit-profile governed-profile))
            (root (agentic-ai-lab-profile-bundle-root 'assurance-root bundle)))
       (check-equal? (.ref root 'name) 'assurance-root)
       (check-equal? (.ref root 'profiles)
                     (list audit-profile governed-profile))
       (check-equal? (eq? (.ref root 'profile-bundle) bundle) #t)
       (check-equal? (.ref root 'runtime-executed?) #f)))
   (yuanxu-test-case "domain string identities remain valid direct Profile keys"
     (let (bundle (compose profiles string-identity-profile))
       (check-equal? (.ref bundle 'profile-identities)
                     '(example/profile))))
   (yuanxu-test-case "closed Scenario Case presents one effective Stage first"
     (let* ((base-stages (.o triage: 'human-review))
            (refined-stages (.o triage: 'clinician-review
                                audit: 'retain-evidence))
            (base-profile
             (.o identity: 'base-stage-profile stages: base-stages))
            (refined-profile
             (.o identity: 'refined-stage-profile stages: refined-stages))
            (bundle (compose profiles base-profile refined-profile))
            (case-value (agentic-ai-lab-profile-bundle-root 'clinical-case bundle))
            (effective-stages (.ref case-value 'stages))
            (sources
             (.o effective: (.o prototype: effective-stages
                                source-path: "yuanxu/profile-composition/profile-bundle.ss"
                                source-line: 236)
                 base: (.o prototype: base-stages
                           source-path: "t/profile-bundle-test.ss"
                           source-line: 119)
                 refined: (.o prototype: refined-stages
                              source-path: "t/profile-bundle-test.ss"
                              source-line: 120)))
            (ordinary
             (yuanxu-slot-presentation effective-stages 'triage))
            (detailed
             (yuanxu-slot-presentation
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
