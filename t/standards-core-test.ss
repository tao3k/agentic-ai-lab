;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/standards/interface)

(export standards-core-test)

(def test-family
  (agentic-ai-lab-standard-family
   "test/standard-family" "test-owner" 'test
   '(scheme json xml) "Apache-2.0" '()))

(def empty-digest (agentic-ai-lab-standard-digest 'empty))
(def terminology-digest (agentic-ai-lab-standard-digest 'terminology-snapshot))

(def (test-artifact-ref identity payload dependencies loader-count-box
                        delay-seconds)
  (let (digest (agentic-ai-lab-standard-digest payload))
    (let (size-bytes
          (string-length
           (call-with-output-string (lambda (port) (write payload port)))))
      (agentic-ai-lab-standard-artifact-ref
       identity identity "1" 'test-artifact 'scheme digest dependencies
       size-bytes
       (lambda ()
         (when (> delay-seconds 0) (thread-sleep! delay-seconds))
         (vector-set! loader-count-box 0 (+ 1 (vector-ref loader-count-box 0)))
         (agentic-ai-lab-standard-artifact-source
          identity digest 'scheme payload size-bytes '()))
       (lambda (source)
         (agentic-ai-lab-standard-artifact
          identity digest 'scheme (.ref source 'payload) '()))
       '()))))

(def (test-edition identity canonical version digest dependencies artifacts roots)
  (agentic-ai-lab-standard-edition-ref
   identity test-family canonical version "test-release" 'global digest
   identity dependencies artifacts roots 'active '() '()))

(def (test-failure-code receipt)
  (.ref (car (.ref receipt 'failures)) 'code))

(def standards-core-test
  (test-suite "Agentic AI Lab Standards core"
    (yuanxu-test-case "resolution closes exact editions and artifact dependencies"
      (let* ((loads (vector 0))
             (base-artifact
              (test-artifact-ref "test/artifact/base" '(base) '() loads 0))
             (leaf-artifact
              (test-artifact-ref
               "test/artifact/leaf" '(leaf) '("test/artifact/base") loads 0))
             (base
              (test-edition
               "test/edition/base" "https://example.test/base" "1" empty-digest
               '() (list base-artifact) '("test/artifact/base")))
             (leaf
              (test-edition
               "test/edition/leaf" "https://example.test/leaf" "1"
               (agentic-ai-lab-standard-digest 'leaf)
               '("test/edition/base") (list leaf-artifact)
               '("test/artifact/leaf")))
             (catalog
              (agentic-ai-lab-standard-catalog "test/catalog" (list base leaf) '()))
             (receipt
              (agentic-ai-lab-standard-resolve
               catalog '("test/edition/leaf")
               (agentic-ai-lab-standard-budget 8 8 8 4096 128)
               terminology-digest))
             (bundle (agentic-ai-lab-standard-resolution-receipt-bundle receipt)))
        (check-equal? (agentic-ai-lab-standard-resolution-receipt? receipt) #t)
        (check-equal? (agentic-ai-lab-standard-bundle? bundle) #t)
        (check-equal? (agentic-ai-lab-standard-resolution-receipt-valid? receipt) #t)
        (check-equal? (.ref bundle 'edition-count) 2)
        (check-equal? (.ref bundle 'artifact-count) 2)
        (check-equal? (map (lambda (value) (.ref value 'identity))
                           (.ref bundle 'editions))
                      '("test/edition/base" "test/edition/leaf"))
        (check-equal?
         (.ref bundle 'closure-digest)
         (agentic-ai-lab-standard-digest
          (list
           'agentic-ai-lab.standard-bundle.v1
           (map
            (lambda (edition)
              (list (.ref edition 'identity)
                    (.ref edition 'canonical-uri)
                    (.ref edition 'version)
                    (.ref edition 'digest)))
            (.ref bundle 'editions))
           (map
            (lambda (artifact)
              (list (.ref artifact 'identity) (.ref artifact 'digest)))
            (.ref bundle 'artifacts))
           terminology-digest)))
        (check-exception
         (agentic-ai-lab-standard-bundle
          (.ref bundle 'root-identities)
          (.ref bundle 'editions)
          3
          (.ref bundle 'artifacts)
          2
          (.ref bundle 'terminology-snapshot-digest)
          (.ref bundle 'byte-count)
          (.ref bundle 'maximum-depth)
          (.ref bundle 'operation-count)
          (.ref bundle 'closure-digest))
         true)
        (check-equal? (vector-ref loads 0) 0)))
    (yuanxu-test-case "edition roots must name declared artifacts"
      (let* ((loads (vector 0))
             (artifact
              (test-artifact-ref
               "test/artifact/declared" '(declared) '() loads 0)))
        (check-exception
         (test-edition
          "test/edition/invalid-root" "https://example.test/invalid-root"
          "1" empty-digest '() (list artifact)
          '("test/artifact/missing"))
         true)))
    (yuanxu-test-case "missing, cyclic, conflicting, and over-budget closures fail closed"
      (let* ((a
              (test-edition
               "test/cycle/a" "https://example.test/cycle/a" "1"
               (agentic-ai-lab-standard-digest 'cycle-a) '("test/cycle/b") '() '()))
             (b
              (test-edition
               "test/cycle/b" "https://example.test/cycle/b" "1"
               (agentic-ai-lab-standard-digest 'cycle-b) '("test/cycle/a") '() '()))
             (same-a
              (test-edition
               "test/conflict/a" "https://example.test/conflict" "1"
               (agentic-ai-lab-standard-digest 'conflict-a) '() '() '()))
             (same-b
              (test-edition
               "test/conflict/b" "https://example.test/conflict" "1"
               (agentic-ai-lab-standard-digest 'conflict-b) '() '() '()))
             (budget-root
              (test-edition
               "test/budget/root" "https://example.test/budget/root" "1"
               (agentic-ai-lab-standard-digest 'budget-root)
               '("test/conflict/a") '() '()))
             (catalog
              (agentic-ai-lab-standard-catalog
               "test/catalog/failures"
               (list a b same-a same-b budget-root) '()))
             (budget (agentic-ai-lab-standard-budget 8 8 8 4096 128)))
        (check-equal?
         (test-failure-code
          (agentic-ai-lab-standard-resolve
           catalog '("test/missing") budget terminology-digest))
         'standard-dependency-missing)
        (check-equal?
         (test-failure-code
          (agentic-ai-lab-standard-resolve
           catalog '("test/cycle/a") budget terminology-digest))
         'standard-dependency-cycle)
        (check-equal?
         (test-failure-code
          (agentic-ai-lab-standard-resolve
           catalog '("test/conflict/a" "test/conflict/b")
           budget terminology-digest))
         'standard-identity-conflict)
        (check-equal?
         (test-failure-code
          (agentic-ai-lab-standard-resolve
           catalog '("test/budget/root")
           (agentic-ai-lab-standard-budget 1 8 8 4096 128) terminology-digest))
         'standard-budget-exceeded)))
    (yuanxu-test-case "artifact, depth, byte, and computation budgets fail independently"
      (let* ((loads (vector 0))
             (base-artifact
              (test-artifact-ref "test/budget/artifact/base" '(base) '() loads 0))
             (leaf-artifact
              (test-artifact-ref
               "test/budget/artifact/leaf" '(leaf)
               '("test/budget/artifact/base") loads 0))
             (edition
              (test-edition
               "test/budget/edition" "https://example.test/budget" "1"
               empty-digest '() (list base-artifact leaf-artifact)
               '("test/budget/artifact/leaf")))
             (catalog
              (agentic-ai-lab-standard-catalog
               "test/catalog/budgets" (list edition) '())))
        (for-each
         (lambda (budget)
           (check-equal?
            (test-failure-code
             (agentic-ai-lab-standard-resolve
              catalog '("test/budget/edition") budget terminology-digest))
            'standard-budget-exceeded))
         (list (agentic-ai-lab-standard-budget 8 1 8 4096 128)
               (agentic-ai-lab-standard-budget 8 8 1 4096 128)
               (agentic-ai-lab-standard-budget 8 8 8 1 128)
               (agentic-ai-lab-standard-budget 8 8 8 4096 1)))))
    (yuanxu-test-case "materialization is explicit, dependency-aware, cached, and evictable"
      (let* ((loads (vector 0))
             (dependency
              (test-artifact-ref "test/load/base" '(base) '() loads 0))
             (root
              (test-artifact-ref
               "test/load/root" '(root) '("test/load/base") loads 0))
             (context
              (agentic-ai-lab-standard-materialization-context
               "test/materialization" (list dependency root)))
             (root-load
              (agentic-ai-lab-standard-load-source context "test/load/root"))
             (after-source-load
              (agentic-ai-lab-standard-materialization-stats context))
             (first (agentic-ai-lab-standard-materialize context "test/load/root"))
             (second (agentic-ai-lab-standard-materialize context "test/load/root")))
        (check-equal? (agentic-ai-lab-standard-load-receipt? root-load) #t)
        (check-equal? (.ref root-load 'valid?) #t)
        (check-equal? (.ref after-source-load 'source-load-count) 1)
        (check-equal? (.ref after-source-load 'materialization-count) 0)
        (check-equal? (.ref first 'valid?) #t)
        (check-equal? (.ref first 'cache-outcome) 'materialized)
        (check-equal? (.ref second 'cache-outcome) 'cache-hit)
        (check-equal? (agentic-ai-lab-standard-load-receipt?
                       (.ref first 'load-receipt))
                      #t)
        (check-equal? (.ref (.ref first 'load-receipt) 'outcome) 'loaded)
        (check-equal? (.ref (.ref first 'load-receipt) 'runtime-executed?) #t)
        (check-equal? (.ref first 'load-receipt) root-load)
        (check-equal? (.ref second 'load-receipt) (.ref first 'load-receipt))
        (check-equal? (.ref first 'generation)
                      (.ref (.ref first 'load-receipt) 'generation))
        (check-equal? (vector-ref loads 0) 2)
        (check-equal? (.ref (agentic-ai-lab-standard-materialization-stats context)
                            'load-count)
                      2)
        (check-equal? (.ref (agentic-ai-lab-standard-materialization-stats context)
                            'materialization-count)
                      2)
        (check-equal? (agentic-ai-lab-standard-evict! context "test/load/root") #t)
        (check-equal?
         (.ref (agentic-ai-lab-standard-materialize context "test/load/root")
               'cache-outcome)
         'materialized)
        (check-equal? (vector-ref loads 0) 3)))
    (yuanxu-test-case "recursive materialization returns a typed re-entry diagnostic"
      (let* ((payload '(recursive-value))
             (digest (agentic-ai-lab-standard-digest payload))
             (size-bytes
              (string-length
               (call-with-output-string (lambda (port) (write payload port)))))
             (nested-receipt #f)
             (context #f)
             (artifact-ref
              (agentic-ai-lab-standard-artifact-ref
               "test/load/reentry" "test/load/reentry" "1"
               'test-artifact 'scheme digest '() size-bytes
               (lambda ()
                 (agentic-ai-lab-standard-artifact-source
                  "test/load/reentry" digest 'scheme payload size-bytes '()))
               (lambda (source)
                 (set! nested-receipt
                       (agentic-ai-lab-standard-materialize
                        context "test/load/reentry"))
                 (agentic-ai-lab-standard-artifact
                  "test/load/reentry" digest 'scheme
                  (.ref source 'payload) '()))
               '())))
        (set! context
              (agentic-ai-lab-standard-materialization-context
               "test/materialization/reentry" (list artifact-ref)))
        (let (outer-receipt
              (agentic-ai-lab-standard-materialize context "test/load/reentry"))
          (check-equal? (.ref outer-receipt 'valid?) #t)
          (check-equal? (.ref nested-receipt 'valid?) #f)
          (check-equal? (test-failure-code nested-receipt)
                        'standard-lazy-reentry)
          (check-equal? (.ref nested-receipt 'runtime-executed?) #f))))
    (yuanxu-test-case "concurrent materialization is single-flight"
      (let* ((loads (vector 0))
             (artifact
              (test-artifact-ref "test/load/concurrent" '(value) '() loads 0.05))
             (context
              (agentic-ai-lab-standard-materialization-context
               "test/materialization/concurrent" (list artifact)))
             (left #f)
             (right #f)
             (left-thread
              (make-thread
               (lambda ()
                 (set! left
                       (agentic-ai-lab-standard-materialize
                        context "test/load/concurrent")))))
             (right-thread
              (make-thread
               (lambda ()
                 (set! right
                       (agentic-ai-lab-standard-materialize
                        context "test/load/concurrent"))))))
        (thread-start! left-thread)
        (thread-start! right-thread)
        (thread-join! left-thread)
        (thread-join! right-thread)
        (check-equal? (.ref left 'valid?) #t)
        (check-equal? (.ref right 'valid?) #t)
        (check-equal? (vector-ref loads 0) 1)
        (check-equal? (.ref (agentic-ai-lab-standard-materialization-stats context)
                            'load-count)
                      1)
        (check-equal? (> (.ref (agentic-ai-lab-standard-materialization-stats context)
                               'wait-count)
                         0)
                      #t)))
    (yuanxu-test-case "loader rejects a digest-mismatched artifact and caches failure"
      (let* ((expected (agentic-ai-lab-standard-digest 'expected))
             (actual (agentic-ai-lab-standard-digest 'actual))
             (materializations (vector 0))
             (artifact-ref
              (agentic-ai-lab-standard-artifact-ref
               "test/load/mismatch" "test/load/mismatch" "1" 'test-artifact
               'scheme expected '() 1
               (lambda ()
                 (agentic-ai-lab-standard-artifact-source
                  "test/load/mismatch" actual 'scheme 'actual 1 '()))
               (lambda (source)
                 (vector-set! materializations 0
                              (+ 1 (vector-ref materializations 0)))
                 (agentic-ai-lab-standard-artifact
                  "test/load/mismatch" (.ref source 'digest)
                  'scheme (.ref source 'payload) '()))
               '()))
             (context
              (agentic-ai-lab-standard-materialization-context
               "test/materialization/mismatch" (list artifact-ref)))
             (first
              (agentic-ai-lab-standard-materialize context "test/load/mismatch"))
             (second
              (agentic-ai-lab-standard-materialize context "test/load/mismatch")))
        (check-equal? (.ref first 'valid?) #f)
        (check-equal? (test-failure-code first)
                      'standard-source-digest-mismatch)
        (check-equal? (.ref (.ref first 'load-receipt) 'valid?) #f)
        (check-equal? (vector-ref materializations 0) 0)
        (check-equal? (.ref second 'cache-outcome) 'failure-cache-hit)))
    (yuanxu-test-case "materialization failure preserves the successful load receipt"
      (let* ((payload '(source-value))
             (digest (agentic-ai-lab-standard-digest payload))
             (size-bytes
              (string-length
               (call-with-output-string (lambda (port) (write payload port)))))
             (loads (vector 0))
             (materializations (vector 0))
             (artifact-ref
              (agentic-ai-lab-standard-artifact-ref
               "test/materialization/invalid" "test/materialization/invalid"
               "1" 'test-artifact 'scheme digest '() size-bytes
               (lambda ()
                 (vector-set! loads 0 (+ 1 (vector-ref loads 0)))
                 (agentic-ai-lab-standard-artifact-source
                  "test/materialization/invalid" digest 'scheme payload
                  size-bytes '()))
               (lambda (source)
                 (vector-set! materializations 0
                              (+ 1 (vector-ref materializations 0)))
                 (error "test materializer failure" source))
               '()))
             (context
              (agentic-ai-lab-standard-materialization-context
               "test/materialization/invalid-context" (list artifact-ref)))
             (first
              (agentic-ai-lab-standard-materialize
               context "test/materialization/invalid"))
             (second
              (agentic-ai-lab-standard-materialize
               context "test/materialization/invalid")))
        (check-equal? (.ref first 'valid?) #f)
        (check-equal? (test-failure-code first) 'standard-artifact-invalid)
        (check-equal? (.ref (.ref first 'load-receipt) 'valid?) #t)
        (check-equal? (.ref (.ref first 'load-receipt) 'outcome) 'loaded)
        (check-equal? (vector-ref loads 0) 1)
        (check-equal? (vector-ref materializations 0) 1)
        (check-equal? (.ref second 'cache-outcome) 'failure-cache-hit)
        (check-equal? (.ref second 'load-receipt)
                      (.ref first 'load-receipt))))
    (yuanxu-test-case "content replacement creates a new immutable generation"
      (let* ((old-loads (vector 0))
             (new-loads (vector 0))
             (old-ref
              (test-artifact-ref
               "test/generation/artifact" '(version one) '() old-loads 0))
             (new-ref
              (test-artifact-ref
               "test/generation/artifact" '(version two) '() new-loads 0))
             (old-context
              (agentic-ai-lab-standard-materialization-context
               "test/generation/old" (list old-ref)))
             (new-context
              (agentic-ai-lab-standard-materialization-context
               "test/generation/new" (list new-ref)))
             (old-receipt
              (agentic-ai-lab-standard-materialize
               old-context "test/generation/artifact"))
             (old-generation (.ref old-receipt 'generation))
             (new-receipt
              (agentic-ai-lab-standard-materialize
               new-context "test/generation/artifact")))
        (check-equal? (.ref old-receipt 'valid?) #t)
        (check-equal? (.ref new-receipt 'valid?) #t)
        (check-equal? (string=? (.ref old-ref 'cache-key)
                                (.ref new-ref 'cache-key))
                      #f)
        (check-equal? (string=? old-generation (.ref new-receipt 'generation))
                      #f)
        (check-equal? (.ref old-receipt 'generation) old-generation)
        (check-equal? (.ref (.ref old-receipt 'load-receipt) 'generation)
                      old-generation)))
    (yuanxu-test-case "failure codes are a closed vocabulary"
      (check-exception
       (agentic-ai-lab-standard-failure
        'standard-unknown-failure "test/failure" 'detail '())
       true))
    (yuanxu-test-case "constraint Profiles are exact POO refinement values"
      (let (profile
            (agentic-ai-lab-standard-constraint-profile
             "test/profile" "revision-1" '("test/edition/base")
             '((constraint . required)) '((compatibility . exact))
             '("test/artifact/base") '("test/terminology/base")
             '((source . "test")) 'qualified))
        (check-equal? (agentic-ai-lab-standard-constraint-profile? profile) #t)
        (check-equal?
         (agentic-ai-lab-standard-constraint-profile-identity profile)
         "test/profile")
        (check-equal?
         (agentic-ai-lab-standard-constraint-profile-base-editions profile)
         '("test/edition/base"))
        (check-exception
         (agentic-ai-lab-standard-constraint-profile
         "test/invalid" "revision-1" '() '() '() '() '() '() 'draft)
         true)))
    (yuanxu-test-case "Cases compose exact Profiles and reject revision conflicts"
      (let* ((edition-a
              (test-edition
               "test/profile-composition/a" "https://example.test/profile/a"
               "1" (agentic-ai-lab-standard-digest 'profile-a) '() '() '()))
             (edition-b
              (test-edition
               "test/profile-composition/b" "https://example.test/profile/b"
               "1" (agentic-ai-lab-standard-digest 'profile-b) '() '() '()))
             (catalog
              (agentic-ai-lab-standard-catalog
               "test/profile-composition/catalog"
               (list edition-a edition-b) '()))
             (profile-a
              (agentic-ai-lab-standard-constraint-profile
               "test/profile/a" "1" '("test/profile-composition/a")
               '(constraint-a) '() '("artifact/shared")
               '("terminology/a") '() 'qualified))
             (profile-b
              (agentic-ai-lab-standard-constraint-profile
               "test/profile/b" "1" '("test/profile-composition/b")
               '(constraint-b) '() '("artifact/shared" "artifact/b")
               '("terminology/b") '() 'qualified))
             (receipt
              (agentic-ai-lab-standard-compose-profiles
               "test/case/composed" (list profile-a profile-b) catalog
               (agentic-ai-lab-standard-budget 4 4 4 4096 64)
               terminology-digest))
             (resolution (.ref receipt 'resolution-receipt))
             (conflicting-profile
              (agentic-ai-lab-standard-constraint-profile
               "test/profile/a" "2" '("test/profile-composition/a")
               '(constraint-a-v2) '() '() '() '() 'draft))
             (conflict
              (agentic-ai-lab-standard-compose-profiles
               "test/case/conflict" (list profile-a conflicting-profile)
               catalog (agentic-ai-lab-standard-budget 4 4 4 4096 64)
               terminology-digest)))
        (check-equal?
         (agentic-ai-lab-standard-profile-composition-receipt? receipt) #t)
        (check-equal?
         (agentic-ai-lab-standard-profile-composition-receipt-valid? receipt) #t)
        (check-equal? (.ref receipt 'profile-identities)
                      '("test/profile/a" "test/profile/b"))
        (check-equal? (.ref receipt 'base-editions)
                      '("test/profile-composition/a"
                        "test/profile-composition/b"))
        (check-equal? (.ref receipt 'constraints)
                      '(constraint-a constraint-b))
        (check-equal? (.ref receipt 'artifact-dependencies)
                      '("artifact/shared" "artifact/b"))
        (check-equal?
         (.ref (agentic-ai-lab-standard-resolution-receipt-bundle resolution)
               'edition-count)
         2)
        (check-equal?
         (agentic-ai-lab-standard-profile-composition-receipt-valid? conflict) #f)
        (check-equal? (.ref conflict 'resolution-receipt) #f)
        (check-equal? (test-failure-code conflict)
                      'standard-profile-revision-conflict)))
    (yuanxu-test-case "validation closures bind bundle, provider, subject, and constraints"
      (let* ((edition
              (test-edition
               "test/validation-closure/edition" "https://example.test/validation-closure" "1"
               empty-digest '() '() '()))
             (catalog
              (agentic-ai-lab-standard-catalog "test/validation-closure/catalog" (list edition) '()))
             (resolution
              (agentic-ai-lab-standard-resolve
               catalog '("test/validation-closure/edition")
               (agentic-ai-lab-standard-budget 2 2 2 1024 64)
               terminology-digest))
             (validation-closure
              (agentic-ai-lab-standard-make-validation-closure
               "test/validation-closure" (agentic-ai-lab-standard-resolution-receipt-bundle resolution)
               "test/provider" 'test-subject
               (agentic-ai-lab-standard-digest 'subject)
               '("constraint/a")))
             (closure-receipt
              (agentic-ai-lab-standard-make-validation-closure-receipt
               validation-closure "test-engine" "1"))
             (conformance
              (agentic-ai-lab-standard-conformance-receipt
               #t "test/provider"
               (.ref validation-closure 'validation-closure-digest)
               (.ref validation-closure 'subject-snapshot-digest)
               '("constraint/a") '() '()
               (agentic-ai-lab-standard-digest 'test-conformance)))
             (case-admission
              (agentic-ai-lab-standard-admit-case
               "test/case" (list conformance)
               (list (agentic-ai-lab-standard-digest 'governance-evidence)))))
        (check-equal? (agentic-ai-lab-standard-validation-closure? validation-closure) #t)
        (check-equal? (.ref validation-closure 'runtime-executed?) #f)
        (check-equal? (agentic-ai-lab-standard-digest? (.ref validation-closure 'validation-closure-digest)) #t)
        (check-equal? (agentic-ai-lab-standard-validation-closure-receipt?
                       closure-receipt)
                      #t)
        (check-equal? (.ref closure-receipt 'constraint-count) 1)
        (check-equal? (agentic-ai-lab-standard-case-admission-receipt?
                       case-admission)
                      #t)
        (check-equal? (.ref case-admission 'valid?) #t)))
    (yuanxu-test-case "vertical modules compose the POO Standards module prototype"
      (let ((module
             (agentic-ai-lab-standards-module
              "test/modules/standards" agentic-ai-lab-standard-empty-catalog
              agentic-ai-lab-standard-default-budget (.o test-provider: 'provider))))
        (check-equal? (agentic-ai-lab-standards-module? module) #t)
        (check-equal? (.ref module 'identity) "test/modules/standards")
        (check-equal? (.ref (.ref module 'providers) 'test-provider) 'provider)
        (check-equal?
         (agentic-ai-lab-standard-feature-module?
          (.ref (.ref module 'features) 'migration)) #t)
        (check-equal?
         (.ref (.ref (.ref module 'features) 'migration) 'feature-kind)
         'migration)
        (check-equal? (procedure? (.ref module '.resolve)) #t)))
    (yuanxu-test-case "governance slots are declared, staged, and Agent-writable"
      (let (interface AgenticAILabStandardMigrationGovernanceInterface.)
        (check-equal? (agentic-ai-lab-standard-governance-interface? interface) #t)
        (let* ((declaration
                (agentic-ai-lab-standard-governance-validate
                 interface 'declaration))
               (before
                (agentic-ai-lab-standard-governance-validate interface 'admit)))
          (check-equal? (.ref declaration 'valid?) #t)
          (check-equal? (.ref before 'valid?) #f)
          (check-equal? (.ref before 'missing-slots)
                        '(authority-provider human-authorization
                          proof-assurance conformance audit-receipt)))
        (let* ((proof-binding
                (agentic-ai-lab-standard-governance-binding
                 'proof-assurance "test/proof-owner" 'proof-assurance
                 (agentic-ai-lab-standard-digest 'test-proof-assurance)
                 'qualified #f (.o evidence: 'test)))
               (written
                (agentic-ai-lab-standard-governance-write interface proof-binding))
               (after
                (agentic-ai-lab-standard-governance-validate written 'admit)))
          (check-equal? (.ref after 'valid?) #f)
          (check-equal? (memq 'proof-assurance (.ref after 'missing-slots)) #f)
          (check-exception
           ((.ref interface '.write-governance)
            (agentic-ai-lab-standard-governance-binding
             'undeclared-slot "test/agent" 'invalid
             (agentic-ai-lab-standard-digest 'invalid) 'qualified #f (.o)))
           true))))))
