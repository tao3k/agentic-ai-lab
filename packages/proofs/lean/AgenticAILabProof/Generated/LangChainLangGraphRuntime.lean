-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.LangChainLangGraph

namespace AgenticAILabProof.Generated.LangChainLangGraphRuntime

open AgenticAILabProof.PooC4.LangChainLangGraph

def generatedRuntimeFactRows : List (String × Bool) :=
  [ ("graph.runtime/executed", true)
  , ("graph.runtime/finished", true)
  , ("graph.runtime/loop-fuel-contained", true)
  , ("graph.runtime/handoff-reached", true)
  , ("graph.runtime/sandbox-scope-contained", true)
  , ("graph.runtime/tool-permissions-contained", true)
  , ("graph.runtime/checkpoint-persisted", true)
  , ("graph.runtime/human-approval-sound", true)
  , ("graph.runtime/subagents-parented", true)
  , ("graph.runtime/diagnostics-empty", true)
  , ("graph.runtime/reusable-production-case", true)
  ]

def generatedProductionRuntimeFacts : ProductionRuntimeFacts where
  runtimeExecuted := True
  finished := True
  loopFuelContained := True
  handoffReached := True
  sandboxScopeContained := True
  toolPermissionsContained := True
  checkpointPersisted := True
  humanApprovalSound := True
  subagentsParented := True
  diagnosticsEmpty := True

theorem generatedProductionRuntimeReusable :
    ReusableProductionRuntime generatedProductionRuntimeFacts := by
  repeat constructor

theorem generatedProductionRuntimeCheckpointAndHumanGate :
    generatedProductionRuntimeFacts.checkpointPersisted /\
      generatedProductionRuntimeFacts.humanApprovalSound :=
  production_runtime_has_checkpoint_and_human_gate
    generatedProductionRuntimeReusable

theorem generatedProductionRuntimeScopeAndToolContainment :
    generatedProductionRuntimeFacts.sandboxScopeContained /\
      generatedProductionRuntimeFacts.toolPermissionsContained :=
  production_runtime_has_scope_and_tool_containment
    generatedProductionRuntimeReusable

end AgenticAILabProof.Generated.LangChainLangGraphRuntime
