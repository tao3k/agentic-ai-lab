-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import «40-context-governance-boundary»
import «41-epistemic-consolidation-governance»
import «42-multi-repo-multi-agent-declassification»
import «43-ascent-security-branch-omission-refinement»
import «44-temporal-causal-survival-and-memory-quotient»
import «45-org-sexpr-gql-candidate-exchange-search»
import «46-durable-agenda-session-sandbox-governance»
import «48-progressive-disclosure-and-two-stage-org-repair»
import «49-scoped-detour-funflow-concurrent-shared-context»
import «50-literature-frontier-detour-confinement-and-causal-audit»
import «51-memory-poisoning-quarantine-and-kv-prefix-serialization»
import «47-end-to-end-context-governance-assurance-closure»
import Lean.Util.CollectAxioms
import Lean.Elab.Command

open Lean Elab Command

run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  let prefixes := #[
    `ContextGovernanceBoundary,
    `ContextEpistemicConsolidationGovernance,
    `MultiRepoAgentDeclassification,
    `AscentSecurityBranchOmissionRefinement,
    `TemporalCausalSurvivalMemoryQuotient,
    `OrgSexprGqlCandidateExchange,
    `DurableAgendaSessionSandboxGovernance,
    `ProgressiveDisclosureAndOrgRepair,
    `ScopedDetourFunflowConcurrentContext,
    `DetourTaintConfinementAndCausalAudit,
    `MemoryQuarantineAndKvPrefixSerialization,
    `EndToEndContextGovernanceClosure
  ]
  let mut declCount : Nat := 0
  for (name, _) in environment.constants.toList do
    if prefixes.any (fun p => p.isPrefixOf name) then
      declCount := declCount + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do
          throwError "{name} depends on disallowed axiom {axiomName}"
  if declCount == 0 then
    throwError "Context Governance declarations were not loaded"
  logInfo m!"CONTEXT-GOVERNANCE-LAKE-AXIOM-AUDIT-OK: {declCount} declarations across 12 namespaces"
