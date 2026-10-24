;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Qualification boundary: a mechanism-only Case composes Profiles from two
;;; independently owned industries.  It proves composition and diagnostics but
;;; makes no claim that either Standard applies to the other's industry.
(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref)
        (only-in :std/test check-equal? test-suite)
        (only-in :agentic-ai-lab/modules/standards/interface
                 agentic-ai-lab-standard-budget
                 agentic-ai-lab-standard-catalog
                 agentic-ai-lab-standard-compose-profiles
                 agentic-ai-lab-standard-constraint-profile
                 agentic-ai-lab-standard-digest
                 agentic-ai-lab-standard-edition-ref
                 agentic-ai-lab-standard-profile-composition-receipt?
                 agentic-ai-lab-standard-profile-composition-receipt-valid?
                 agentic-ai-lab-standard-resolution-receipt-bundle)
        (only-in :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/fhir/config
                 FHIRStandardsCatalog)
        (only-in :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/fhir/objects
                 FHIRAUCorePatientStandardProfile)
        (only-in :agentic-ai-lab/lambda-aitia/modules/sdlc/standards/nasa-standard-provider
                 nasa-7150-2d-local-source-provider
                 nasa-7150-2d-standard-provider))

(export standards-multi-industry-profile-composition-test)

(def terminology-snapshot
  (agentic-ai-lab-standard-digest 'cross-industry/no-terminology-evaluation))

(def composition-budget
  (agentic-ai-lab-standard-budget 8 16 8 1000000 256))

(def (failure-code receipt)
  (.ref (car (.ref receipt 'failures)) 'code))

(def standards-multi-industry-profile-composition-test
  (test-suite
   "Multi-industry Standard Profile composition qualification"
   (yuanxu-test-case
    "a Case resolves both industry Profiles as one immutable closure"
    (let* ((nasa-provider
            (nasa-7150-2d-standard-provider
             (nasa-7150-2d-local-source-provider ".")))
           (nasa-profile (.ref nasa-provider 'constraint-profile))
           (nasa-edition (.ref nasa-provider 'edition))
           (catalog
            (agentic-ai-lab-standard-catalog
             "qualification/standards/multi-industry/catalog"
             (append (.ref FHIRStandardsCatalog 'editions)
                     (list nasa-edition))
             '((qualification-purpose . mechanism-only)
               (applicability-inference . prohibited))))
           (receipt
            (agentic-ai-lab-standard-compose-profiles
             "qualification/standards/multi-industry/case"
             (list FHIRAUCorePatientStandardProfile nasa-profile)
             catalog composition-budget terminology-snapshot))
           (bundle
            (agentic-ai-lab-standard-resolution-receipt-bundle
             (.ref receipt 'resolution-receipt))))
      (check-equal?
       (agentic-ai-lab-standard-profile-composition-receipt? receipt) #t)
      (check-equal?
       (agentic-ai-lab-standard-profile-composition-receipt-valid? receipt) #t)
      (check-equal? (.ref receipt 'profile-identities)
                    (list
                     "http://hl7.org.au/fhir/core/StructureDefinition/au-core-patient"
                     "lambda-aitia/nasa-npr-7150.2d/full"))
      (check-equal? (.ref receipt 'base-editions)
                    '("hl7.fhir.au.core@1.0.0"
                      "nasa/npr-7150.2d/2022-03-08"))
      (check-equal? (.ref receipt 'constraint-count) 130)
      (check-equal? (.ref bundle 'edition-count) 4)
      (check-equal? (.ref bundle 'artifact-count) 10)
      (check-equal? (.ref bundle 'runtime-executed?) #f)))
   (yuanxu-test-case
    "a conflicting edition identity fails with the first typed diagnostic"
    (let* ((nasa-provider
            (nasa-7150-2d-standard-provider
             (nasa-7150-2d-local-source-provider ".")))
           (nasa-profile (.ref nasa-provider 'constraint-profile))
           (nasa-edition (.ref nasa-provider 'edition))
           (shadow-identity "qualification/nasa-npr-7150.2d/shadow")
           (shadow-edition
            (agentic-ai-lab-standard-edition-ref
             shadow-identity (.ref nasa-edition 'family)
             (.ref nasa-edition 'canonical-uri) (.ref nasa-edition 'version)
             (.ref nasa-edition 'specification-release)
             (.ref nasa-edition 'jurisdiction)
             (agentic-ai-lab-standard-digest 'tampered-nasa-edition)
             "qualification://tampered" '() '() '() 'active '()
             '((fixture . identity-conflict))))
           (shadow-profile
            (agentic-ai-lab-standard-constraint-profile
             "qualification/nasa-npr-7150.2d/shadow" "1"
             (list shadow-identity) '() '() '() '() '() 'rejected))
           (catalog
            (agentic-ai-lab-standard-catalog
             "qualification/standards/multi-industry/conflict-catalog"
             (append (.ref FHIRStandardsCatalog 'editions)
                     (list nasa-edition shadow-edition))
             '()))
           (receipt
            (agentic-ai-lab-standard-compose-profiles
             "qualification/standards/multi-industry/conflict-case"
             (list FHIRAUCorePatientStandardProfile
                   nasa-profile shadow-profile)
             catalog composition-budget terminology-snapshot)))
      (check-equal?
       (agentic-ai-lab-standard-profile-composition-receipt-valid? receipt) #f)
      (check-equal? (failure-code receipt) 'standard-identity-conflict)
      (check-equal? (.ref receipt 'runtime-executed?) #f)))))
