;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop element?)
        (only-in :yuanxu/contribution/objects
                 admit-contributions)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection)
        (only-in :yuanxu/poo-clos/interface
                 poo-clos-generic-methods
                 poo-clos-make-instance)
        :agentic-ai-lab/modules/governance/interface
        :agentic-ai-lab/modules/authorization/interface
        :agentic-ai-lab/modules/authorization/providers/cedar/interface)

(export governance-core-test)

(def test-digest
  (string-append "sha256:" (make-string 64 #\0)))

(def TestGovernanceProfile
  (.o (:: @ AgenticAILabGovernanceProfile.)
      identity: "test/governance"
      revision: "1"
      owner: "test-owner"
      policies: (.o release: 'review-required)))

(def ExposedPrecondition
  (agentic-ai-lab-governance-precondition
   "test/precondition/external-input" #t "evidence:external-input"))

(def DerivedGovernanceSource
  (.o (:: @ (agentic-ai-lab-governance-source
              "test/source/derived" "sources/derived.json" 'json))
      kind: 'test.derived-governance-source))

(def BlockingThreat
  (agentic-ai-lab-governance-threat
   "test/threat/unreviewed-external-input"
   'critical
   'exposed
   (list ExposedPrecondition)))

(def BlockingThreatModel
  (agentic-ai-lab-governance-threat-model
   "test/threat-model/blocking" (list BlockingThreat)))

(def UnsafeGovernanceProfile
  (.o (:: @ TestGovernanceProfile)
      identity: "test/governance/unsafe"
      threat-model: BlockingThreatModel))

(def TestGovernanceModuleProfile
  (.o (:: @ TestGovernanceProfile)
      identity: "test/governance/module"
      module-family: 'test-governance))

(def TestGovernanceModule
  (agentic-ai-lab-governance-module-contribution
   TestGovernanceModuleProfile 'test-governance
   '(knowledge-governance) '()))

(def (test-proof composition profiles assessments)
  (agentic-ai-lab-cedar-proof-binding
   composition (map (lambda (profile) (.ref profile 'identity)) profiles)
   test-digest test-digest test-digest test-digest
   (agentic-ai-lab-governance-assessments-digest assessments)
   test-digest
   '("test-governance-qualification")))

(def test-context
  (agentic-ai-lab-cedar-authority-context
   "test-authority" "test-runtime" 1 test-digest 0 1 0))

(def test-policy
  (agentic-ai-lab-cedar-policy
   "test-policy"
   "permit(principal, action, resource);"))

(def test-schema
  (agentic-ai-lab-cedar-schema "{}"))

(def test-entities
  (agentic-ai-lab-cedar-entities "[]"))

(def test-capability
  (agentic-ai-lab-cedar-runtime-capability "test::Action" 1))

(def test-elevated-capability
  (agentic-ai-lab-authorization-capability
   "test/capability/release" "test::Action" 1 'elevated))

(def governance-core-test
  (test-suite "Agentic AI Lab Governance core and Cedar Provider boundary"
    (yuanxu-test-case "core prototype requires explicit contributor identity"
      (check-equal?
       (agentic-ai-lab-governance-profile? AgenticAILabGovernanceProfile.) #f)
      (check-equal?
       (agentic-ai-lab-governance-profile? TestGovernanceProfile) #t)
      (check-equal? (element? AgenticAILabGovernanceProfile TestGovernanceProfile)
                    #t)
      (check-equal? (element? AgenticAILabGovernanceThreat BlockingThreat) #t)
      (check-equal? (agentic-ai-lab-governance-source? DerivedGovernanceSource) #t))
    (yuanxu-test-case "Profile generic dispatch produces a typed inert assessment"
      (let (assessment
            (agentic-ai-lab-governance-evaluate
             TestGovernanceProfile (.o request: 'release)))
        (check-equal? (agentic-ai-lab-governance-assessment? assessment) #t)
        (check-equal? (.ref assessment 'handoff-ready?) #t)
        (check-equal? (.ref assessment 'runtime-executed?) #f)))
    (yuanxu-test-case "pre-threat exposure blocks Provider handoff"
      (let (assessment
            (agentic-ai-lab-governance-evaluate
             UnsafeGovernanceProfile (.o request: 'release)))
        (check-equal? (.ref assessment 'handoff-ready?) #f)
        (check-equal?
         (.ref assessment 'unresolved-threats)
         '("test/threat/unreviewed-external-input"))))
    (yuanxu-test-case "observed preconditions require evidence identity"
      (check-exception
       (agentic-ai-lab-governance-precondition "test/precondition/forged" #t #f)
       true))
    (yuanxu-test-case "governance contribution is semantic and inert"
      (let* ((contribution
              (agentic-ai-lab-governance-contribution
               TestGovernanceProfile '(knowledge-governance) '()))
             (receipt (admit-contributions (list contribution) '())))
        (check-equal? (.ref receipt 'accepted?) #t)
        (check-equal? (.ref receipt 'runtime-executed?) #f)))
    (yuanxu-test-case "shared module projection admits only its declared family"
      (let (selection
            (yuanxu-user-module-selection 'custom 'test-governance '()))
        (check-equal?
         (eq? (agentic-ai-lab-governance-module-config
               selection 'test-governance TestGovernanceModule)
              TestGovernanceModule)
         #t)
        (check-exception
         (agentic-ai-lab-governance-module-config
          selection 'other-family TestGovernanceModule)
         true)
        (check-exception
         (agentic-ai-lab-governance-module-contribution
          TestGovernanceModuleProfile 'other-family
          '(knowledge-governance) '())
         true)))
    (yuanxu-test-case "Authorization contracts keep elevated capability strict"
      (check-equal?
       (.ref CedarAuthorizationProvider 'identity)
       "agentic-ai-lab/authorization/cedar")
      (let (receipt
            (agentic-ai-lab-authorization-capability-contract
             CedarAuthorizationProvider
             (list test-elevated-capability)))
        (check-equal? (.ref receipt 'admitted?) #t)
        (check-equal? (.ref receipt 'runtime-executed?) #f)
        ;; Force the lazy slot: lexical names matching POO slot names can
        ;; otherwise hide a recursive capture until a downstream handoff.
        (check-equal?
         (.ref receipt 'contract-digest)
         (agentic-ai-lab-authorization-capabilities-digest
          CedarAuthorizationProvider
          (list test-elevated-capability)))
        (check-equal?
         (agentic-ai-lab-authorization-provider-engines
          CedarAuthorizationProvider)
         '("cedar-rust" "cedar-lean"))))
    (yuanxu-test-case "Authorization Provider publishes its CLOS method bundle"
      (check-equal?
       (length
        (poo-clos-generic-methods AuthorizationCapabilityContractGeneric))
       2)
      (let (unsupported-provider
            (agentic-ai-lab-authorization-provider
             "test/authorization/unsupported"
             '("unsupported")
             'strict-lockstep
             (poo-clos-make-instance
              AuthorizationCapabilityContractExecutor)
             'test.runtime))
        (check-exception
         (agentic-ai-lab-authorization-capability-contract
          unsupported-provider
          (list test-elevated-capability))
         true)))
    (yuanxu-test-case "Cedar adapter binds the exact Governance Profile identity"
      (let* ((profiles (list TestGovernanceProfile))
             (assessments
              (list (agentic-ai-lab-governance-evaluate TestGovernanceProfile (.o))))
             (snapshot
            (agentic-ai-lab-cedar-governance-snapshot
             "test/governance" profiles assessments test-context
             (test-proof "test/governance" profiles assessments)
             (list test-policy) test-schema test-entities
             (list test-capability))))
        (check-equal? (.ref snapshot 'runtime-executed?) #f)
        (check-equal?
         (.ref (car (.ref snapshot 'governance-assessments)) 'handoff-ready?) #t)
        (check-equal?
         (.ref (.ref snapshot 'proof-binding) 'composition)
         "test/governance")))
    (yuanxu-test-case "Cedar capability owns the source-admission requirement"
      (let* ((protected
              (agentic-ai-lab-cedar-runtime-capability
               "test::Action" 1 source-admission-required?: #t))
             (profiles (list TestGovernanceProfile))
             (assessments
              (list (agentic-ai-lab-governance-evaluate
                     TestGovernanceProfile (.o))))
             (snapshot
              (agentic-ai-lab-cedar-governance-snapshot
               "test/governance" profiles assessments test-context
               (test-proof "test/governance" profiles assessments)
               (list test-policy) test-schema test-entities
               (list protected)))
             (runtime
              (agentic-ai-lab-cedar-authority-snapshot->runtime snapshot))
             (capability (vector-ref (hash-get runtime "capabilities") 0)))
        (check-equal? (.ref test-capability 'source-admission-required?) #f)
        (check-equal? (.ref protected 'source-admission-required?) #t)
        (check-equal?
         (hash-get capability "source_admission_required") #t)
        (check-exception
         (agentic-ai-lab-cedar-runtime-capability
          "test::Action" 1 source-admission-required?: 'yes)
         true)))
    (yuanxu-test-case "Cedar adapter rejects another composition"
      (check-exception
       (let* ((profiles (list TestGovernanceProfile))
              (assessments
               (list (agentic-ai-lab-governance-evaluate TestGovernanceProfile (.o)))))
         (agentic-ai-lab-cedar-governance-snapshot
          "test/governance" profiles assessments test-context
          (test-proof "other/governance" profiles assessments)
          (list test-policy) test-schema test-entities (list test-capability)))
       true))
    (yuanxu-test-case "Cedar adapter cannot bypass unresolved Governance threats"
      (check-exception
       (let* ((profiles (list UnsafeGovernanceProfile))
              (assessments
               (list (agentic-ai-lab-governance-evaluate UnsafeGovernanceProfile (.o)))))
         (agentic-ai-lab-cedar-governance-snapshot
          "test/governance/unsafe" profiles assessments test-context
          (test-proof "test/governance/unsafe" profiles assessments)
          (list test-policy) test-schema test-entities (list test-capability)))
       true))))
