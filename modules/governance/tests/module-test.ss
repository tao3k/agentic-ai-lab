;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .cc .o)
        (only-in :gerbil/runtime/loader list-modules)
        (only-in :tao3k/agentic-ai-lab/modules/governance/interface
                 AgenticAILabGovernanceProfile.
                 agentic-ai-lab-governance-evaluate
                 agentic-ai-lab-governance-rule
                 agentic-ai-lab-governance-rule-allow
                 agentic-ai-lab-governance-rule-deny
                 agentic-ai-lab-governance-compose-all
                 agentic-ai-lab-governance-guard-when
                 agentic-ai-lab-governance-context-ref
                 agentic-ai-lab-governance-require-principal-kind
                 agentic-ai-lab-governance-require-actor-roles
                 agentic-ai-lab-governance-require-scope-subset
                 agentic-ai-lab-governance-require-chain-depth-within
                 agentic-ai-lab-governance-rule-threat-model
                 agentic-ai-lab-governance-profile-extend))
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
      (displayln "LAB-GOVERNANCE-PRODUCT-USE-OK"))

    (test-case "higher-order rule combinators produce validated inert assessments"
      (def human-only
        (agentic-ai-lab-governance-require-principal-kind
         "rule/human-only" 'human))
      (def maintainer-only
        (agentic-ai-lab-governance-require-actor-roles
         "rule/maintainer-only" '(owner maintainer)))
      (def guest-scope-cap
        (agentic-ai-lab-governance-guard-when
         "rule/guest-scope-cap"
         (lambda (ctx)
           (eq? (agentic-ai-lab-governance-context-ref ctx 'grant-role) 'external-guest))
         (agentic-ai-lab-governance-require-scope-subset
          "rule/guest-public-only" 'grant-scopes '("public"))))
      (def depth-guard
        (agentic-ai-lab-governance-require-chain-depth-within
         "rule/bot-depth" 'bot-chain-depth 2))
      (def composed
        (agentic-ai-lab-governance-compose-all
         "rule/composed-gate"
         (list human-only maintainer-only guest-scope-cap depth-guard)))
      (def model
        (agentic-ai-lab-governance-rule-threat-model
         "threat-model/higher-order-test"
         (list composed)))
      (def profile
        (agentic-ai-lab-governance-profile-extend
         AgenticAILabGovernanceProfile.
         identity: "governance/higher-order-profile"
         revision: "1"
         owner: "Lab"
         threat-model: model))

      ;; Agent actor must fail closed
      (def bot-assessment
        (agentic-ai-lab-governance-evaluate
         profile
         (.o actor-kind: 'agent actor-role: 'owner
             grant-role: 'external-guest grant-scopes: '("public")
             bot-chain-depth: 0)))
      (check-equal? (.get bot-assessment handoff-ready?) #f)
      (check-equal? (.get bot-assessment runtime-executed?) #f)

      ;; Scope escalation on external guest must fail closed
      (def escalation-assessment
        (agentic-ai-lab-governance-evaluate
         profile
         (.o actor-kind: 'human actor-role: 'owner
             grant-role: 'external-guest grant-scopes: '("org:core")
             bot-chain-depth: 0)))
      (check-equal? (.get escalation-assessment handoff-ready?) #f)

      ;; Valid human owner passes assessment (still inert: runtime-executed? #f)
      (def ok-assessment
        (agentic-ai-lab-governance-evaluate
         profile
         (.o actor-kind: 'human actor-role: 'owner
             grant-role: 'external-guest grant-scopes: '("public")
             bot-chain-depth: 1)))
      (check-equal? (.get ok-assessment handoff-ready?) #t)
      (check-equal? (.get ok-assessment runtime-executed?) #f))))
