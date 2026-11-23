-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Lake
open Lake DSL

package «agentic-ai-lab-context-governance-proofs» where
  version := v!"0.1.0"
  moreLeanArgs := #["-DautoImplicit=false", "-DwarningAsError=true"]

@[default_target]
lean_lib ContextGovernanceChain where
  srcDir := "../../docs/10-19-design/10.06-poo-module-system/agentic-ai-context"
  roots := #[
    `«40-context-governance-boundary»,
    `«41-epistemic-consolidation-governance»,
    `«42-multi-repo-multi-agent-declassification»,
    `«43-ascent-security-branch-omission-refinement»,
    `«44-temporal-causal-survival-and-memory-quotient»,
    `«45-org-sexpr-gql-candidate-exchange-search»,
    `«46-durable-agenda-session-sandbox-governance»,
    `«48-progressive-disclosure-and-two-stage-org-repair»,
    `«47-end-to-end-context-governance-assurance-closure»
  ]
