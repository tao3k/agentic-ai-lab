;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .cc .o)
        (only-in :gerbil/runtime/loader list-modules)
        (only-in :tao3k/agentic-ai-lab/modules/governance/interface
                 AgenticAILabGovernanceProfile. agentic-ai-lab-governance-evaluate))
(export governance-module-test)
(def governance-module-test
  (test-suite "Selected Governance public API"
    (test-case "declared Profile produces an inert release assessment"
      (def profile
        (.cc AgenticAILabGovernanceProfile.
             identity: "governance/module-test" revision: "1" owner: "Lab"))
      (def context (.o request: 'release))
      (def assessment (agentic-ai-lab-governance-evaluate profile context))
      (check-equal? (.get assessment profile-identity) "governance/module-test")
      (check-equal? (eq? (.get assessment context) context) #t)
      (check-equal? (.get assessment handoff-ready?) #t)
      (check-equal? (.get assessment runtime-executed?) #f)
      ;; This Suite is the ordinary native-import consumer. The separate
      ;; Module System .get process evaluates Interface as source configuration.
      (def library (string-append (path-strip-trailing-directory-separator
                                   (path-normalize (path-expand "lib" (gerbil-path)))) "/"))
      (def loaded (assoc "tao3k/agentic-ai-lab/modules/governance/interface~0" (list-modules)))
      (check-equal? (and loaded (string? (cdr loaded))
                        (string-prefix? library (path-normalize (cdr loaded)))) #t)
      (displayln "LAB-GOVERNANCE-PRODUCT-USE-OK"))))
