;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public Governance core interface.  Cedar remains a Provider boundary.
(import "types.ss" "objects.ss" "funs.ss" "config.ss"
        "policy/higher-order-rules.ss")
(export (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss")
        (import: "policy/higher-order-rules.ss"))
(export Governance)

(.def Governance
  identity: 'governance
  tags: '(governance)
  core: (.o
            scope-contract: GovernanceScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/governance/interface
                         Profile: AgenticAILabGovernanceProfile.
                         evaluate: agentic-ai-lab-governance-evaluate
                         rule: agentic-ai-lab-governance-rule
                         compose-all: agentic-ai-lab-governance-compose-all
                         compose-any: agentic-ai-lab-governance-compose-any
                         guard-when: agentic-ai-lab-governance-guard-when
                         rule-threat-model: agentic-ai-lab-governance-rule-threat-model
                         extend-profile: agentic-ai-lab-governance-profile-extend))
  features: (.o))
