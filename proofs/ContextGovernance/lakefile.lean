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
    `«49-scoped-detour-funflow-concurrent-shared-context»,
    `«50-literature-frontier-detour-confinement-and-causal-audit»,
    `«51-memory-poisoning-quarantine-and-kv-prefix-serialization»,
    `«52-funflow-cas-singleflight-and-external-sandbox-binding»,
    `«53-yuanxu-c4-profile-convergence-and-interface-slots»,
    `«54-durable-work-engine-core-challenge»,
    `«55-mcp-tool-poisoning-and-camel-capability-flow»,
    `«56-ascent-governed-loop-termination»,
    `«57-obligation-fixpoint-reconciler»,
    `«58-delegation-attenuation-and-cedar-toctou-fence»,
    `«59-graph-engine-convergent-tree-and-apex-join»,
    `«60-unified-cyclic-scc-and-durable-tree-recovery»,
    `«47-end-to-end-context-governance-assurance-closure»
  ]
