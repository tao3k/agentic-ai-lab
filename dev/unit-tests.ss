#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export main)

(import (only-in :clan/poo/object .cc)
        (only-in :std/cli/multicall call-entry-point)
        (only-in :asp-gerbil-scheme/testing-api
                 +testing-discovery-profile+
                 +testing-process-isolation-profile+
                 +testing-serial-resource-profile+
                 testing-test-selector
                 testing-interface-add-profile
                 testing-interface-map-profile)
        (only-in :asp-gerbil-scheme/testing-runner-api
                 init-profiled-test-environment!)
        (only-in :agentic-ai-lab/dev/testing-api
                 +agentic-ai-lab-testing-interface+))

(def +agentic-ai-lab-serial-test-selectors+
  (map (lambda (fragment) (testing-test-selector 'contains fragment))
       '("module-object-practice-test.ss"
         "module-system-lazy-loader-test.ss"
         "module-system-observability-test.ss")))

(def +agentic-ai-lab-serial-testing-interface+
  (foldl
    (lambda (selector testing)
      (testing-interface-map-profile
       testing selector +testing-serial-resource-profile+))
    (testing-interface-add-profile
      +agentic-ai-lab-testing-interface+
      (.cc +testing-discovery-profile+
           ignoreDirectories: '("t/qualification/ascent-integration"
                                ;; Explicit installed native artifact/performance gate.
                                "t/qualification/temporal-mrr-native"
                                "packages/lambda-episteme"
                                "packages/lambda-aitia"
                                "core"
                                "t/performance"
                                ;; This external qualification requires the
                                ;; explicitly pinned FHIR Validator JAR and is
                                ;; owned by `just check-healthcare-fhir-reference-validator`.
                                "t/qualification/healthcare-fhir-reference-validator"
                                ;; Healthcare parser and migration assurance
                                ;; qualifications inject their pinned
                                ;; gerbil-parser and Lambda Episteme loadpaths
                                ;; through dedicated Just gates.
                                "t/qualification/healthcare-fhirpath-syntax"
                                "t/qualification/healthcare-hl7v2-migration"
                                "t/qualification/standards-multi-industry"
                                "t/module-system-poo-performance-test-support")))
    +agentic-ai-lab-serial-test-selectors+))

(def +agentic-ai-lab-project-testing-interface+
  ;; A repository-sized batch retains all imported test modules in one VM.
  ;; Keep each file within the original 1 GiB worker allowance; ASP still
  ;; owns discovery, bounded concurrency, serial-resource policy and gxtest.
  (testing-interface-add-profile
   +agentic-ai-lab-serial-testing-interface+
   +testing-process-isolation-profile+))

(init-profiled-test-environment! +agentic-ai-lab-project-testing-interface+)

;; The ASP declaration installs the selected entry point.  V19's script
;; launcher looks up a caller-visible `main`, so expose that trampoline here.
(def (main . args)
  (apply call-entry-point args))
