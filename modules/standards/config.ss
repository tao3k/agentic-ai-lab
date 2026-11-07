;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Standard core owns the composable module prototype, but no ambient industry
;;; catalog or concrete validation Provider.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        "types.ss"
        "objects.ss"
        "funs.ss"
        "loader.ss")

(export agentic-ai-lab-standard-default-budget
        agentic-ai-lab-standard-empty-catalog
        AgenticAILabStandardGovernanceInterface.
        AgenticAILabStandardMigrationGovernanceInterface.
        AgenticAILabStandardFeatureModule.
        AgenticAILabStandardMigrationFeatureModule.
        AgenticAILabStandardsModule.
        agentic-ai-lab-standards-module)

(def agentic-ai-lab-standard-default-budget
  (agentic-ai-lab-standard-budget 64 4096 64 (* 64 1024 1024) 100000))

(def agentic-ai-lab-standard-empty-catalog
  (agentic-ai-lab-standard-catalog "agentic-ai-lab/standard/empty" '() '()))

;;; Feature modules are composable children of the Standards module.  Core
;;; declares stable extension points; vertical owners add fixtures and methods.
(def AgenticAILabStandardGovernanceInterface.
  (agentic-ai-lab-standard-governance-interface
   "agentic-ai-lab/modules/standards/governance/base"
   '() '(documentation presentation-metadata reference-implementation)
   (.o declaration: (.o))
   (.o)
   (lambda (_binding) #t)))

(def AgenticAILabStandardFeatureModule.
  (agentic-ai-lab-standard-feature-module
   "agentic-ai-lab/modules/standards/features/base" 'base '() (.o)
   AgenticAILabStandardGovernanceInterface. '()))

(def AgenticAILabStandardMigrationGovernanceInterface.
  (agentic-ai-lab-standard-governance-interface
   "agentic-ai-lab/modules/standards/features/migration/governance"
   '(authority-provider human-authorization proof-assurance conformance
     audit-receipt)
   '(documentation presentation-metadata reference-implementation
     non-authoritative-analysis)
   (.o declaration: (.o)
       review:
       (.o proof-assurance: '(qualified admitted)
           conformance: '(qualified admitted))
       admit:
       (.o authority-provider: '(qualified admitted)
           human-authorization: '(qualified admitted)
           proof-assurance: '(qualified admitted)
           conformance: '(qualified admitted)
           audit-receipt: '(qualified admitted))
       cutover:
       (.o authority-provider: '(admitted)
           human-authorization: '(admitted)
           proof-assurance: '(admitted)
           conformance: '(admitted)
           audit-receipt: '(admitted)))
   (.o)
   (lambda (_binding) #t)))

(def AgenticAILabStandardMigrationFeatureModule.
  (agentic-ai-lab-standard-feature-module
   "agentic-ai-lab/modules/standards/features/migration" 'migration
   '(source-adapter mapping-proposal human-review conformance admission
     governance fixture)
   (.o) AgenticAILabStandardMigrationGovernanceInterface.
   '((owner . agentic-ai-lab-standards))))

;;; This is the Lego stud exposed by Agentic AI Lab.  Vertical contributors derive a
;;; module object and replace only catalog, budget and Provider slots.
(def AgenticAILabStandardsModule.
  (.o (:: self)
      kind: +agentic-ai-lab-standards-module-kind+
      identity: "agentic-ai-lab/modules/standards"
      catalog: agentic-ai-lab-standard-empty-catalog
      budget: agentic-ai-lab-standard-default-budget
      providers: (.o)
      features: (.o migration: AgenticAILabStandardMigrationFeatureModule.)
      .resolve:
      (lambda (root-identities terminology-snapshot-digest)
        (agentic-ai-lab-standard-resolve
         catalog root-identities budget terminology-snapshot-digest))
      .materialization-context:
      (lambda (identity bundle)
        (agentic-ai-lab-standard-materialization-context
         identity (.ref bundle 'artifacts)))
      .make-validation-closure:
      (lambda (identity bundle provider-identity subject-kind
                        subject-snapshot-digest constraints)
        (agentic-ai-lab-standard-make-validation-closure
         identity bundle provider-identity subject-kind
         subject-snapshot-digest constraints))))

(def (agentic-ai-lab-standards-module identity-value catalog-value budget-value
                                provider-values
                                (feature-values
                                 (.o migration:
                                     AgenticAILabStandardMigrationFeatureModule.)))
  (validate
   AgenticAILabStandardsModule
   (.o (:: @ AgenticAILabStandardsModule.)
       identity: identity-value
       catalog: catalog-value
       budget: budget-value
       providers: provider-values
       features: feature-values)))
