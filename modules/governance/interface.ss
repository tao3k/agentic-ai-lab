;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public Governance core interface.  Cedar remains a Provider boundary.
(import "types.ss" "objects.ss" "funs.ss" "config.ss")
(export (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def Governance
  identity: 'governance
  tags: '(governance)
  core: (.o requires: (.o)
            scope-contract: GovernanceScope
            exports: (.o library: 'agentic-ai-lab/modules/governance/interface
                         Profile: AgenticAILabGovernanceProfile.
                         evaluate: agentic-ai-lab-governance-evaluate))
  features: (.o))
