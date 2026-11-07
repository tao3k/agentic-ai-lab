-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.AgentLifecycleTopology

namespace AgenticAILabProof.PooC4.LangChainLangGraph

/-!
LangChain/LangGraph reference profiles in Agentic AI Lab are proof targets, not
framework clones. The useful theorem is that a small POO profile can express
linear chain progression, guarded graph topology, and lane containment while
reusing the same lifecycle gate.
-/

universe u1 u2 u3

structure ChainProfileFacts (Step : Type u1) where
  entryStep : Step
  toolStep : Step
  answerStep : Step
  dependsOn : Step -> Step -> Prop
  before : Step -> Step -> Prop

structure SoundChainProfile
    {Step : Type u1}
    (facts : ChainProfileFacts Step) : Prop where
  toolDependsOnEntry :
    facts.dependsOn facts.toolStep facts.entryStep
  answerDependsOnTool :
    facts.dependsOn facts.answerStep facts.toolStep
  dependencyProgress :
    forall later earlier,
      facts.dependsOn later earlier ->
        facts.before earlier later

theorem langchain_core_has_ordered_progression
    {Step : Type u1}
    {facts : ChainProfileFacts Step}
    (h : SoundChainProfile facts) :
    facts.before facts.entryStep facts.toolStep /\
      facts.before facts.toolStep facts.answerStep := by
  exact And.intro
    (h.dependencyProgress
      facts.toolStep
      facts.entryStep
      h.toolDependsOnEntry)
    (h.dependencyProgress
      facts.answerStep
      facts.toolStep
      h.answerDependsOnTool)

theorem missing_chain_dependency_contradicts_soundness
    {Step : Type u1}
    {facts : ChainProfileFacts Step}
    (h : SoundChainProfile facts)
    (hmissing : Not (facts.dependsOn facts.toolStep facts.entryStep)) :
    False := by
  exact hmissing h.toolDependsOnEntry

structure GraphProfileFacts (Node : Type u1) where
  startNode : Node
  finishNode : Node
  edge : Node -> Node -> Prop
  guarded : Node -> Node -> Prop
  reachesFinish : Node -> Prop

structure SoundGraphProfile
    {Node : Type u1}
    (facts : GraphProfileFacts Node) : Prop where
  everyEdgeGuarded :
    forall fromNode toNode,
      facts.edge fromNode toNode ->
        facts.guarded fromNode toNode
  startReachesFinish :
    facts.reachesFinish facts.startNode
  finishIsReachable :
    facts.reachesFinish facts.finishNode

theorem langgraph_core_has_guarded_finish_path
    {Node : Type u1}
    {facts : GraphProfileFacts Node}
    (h : SoundGraphProfile facts) :
    facts.reachesFinish facts.startNode /\
      facts.reachesFinish facts.finishNode := by
  exact And.intro h.startReachesFinish h.finishIsReachable

theorem unguarded_graph_edge_contradicts_soundness
    {Node : Type u1}
    {facts : GraphProfileFacts Node}
    (h : SoundGraphProfile facts)
    {fromNode toNode : Node}
    (hedge : facts.edge fromNode toNode)
    (hunguarded : Not (facts.guarded fromNode toNode)) :
    False := by
  exact hunguarded (h.everyEdgeGuarded fromNode toNode hedge)

inductive LangChainStep where
  | memory
  | prompt
  | model
  | parser
  | parsedOutput
deriving Repr, DecidableEq

def LangChainRank : LangChainStep -> Nat
  | .memory => 0
  | .prompt => 1
  | .model => 2
  | .parser => 3
  | .parsedOutput => 4

def LangChainDependsOn : LangChainStep -> LangChainStep -> Prop
  | .prompt, .memory => True
  | .model, .prompt => True
  | .parser, .model => True
  | .parsedOutput, .parser => True
  | _, _ => False

def LangChainBefore (earlier later : LangChainStep) : Prop :=
  LangChainRank earlier < LangChainRank later

theorem langchain_ui_dependency_progress :
    forall later earlier,
      LangChainDependsOn later earlier ->
        LangChainBefore earlier later := by
  intro later earlier h
  cases later <;> cases earlier <;>
    simp [LangChainDependsOn, LangChainBefore, LangChainRank] at h ⊢

theorem langchain_ui_linear_chain_order :
    LangChainBefore .memory .prompt /\
      LangChainBefore .prompt .model /\
      LangChainBefore .model .parser /\
      LangChainBefore .parser .parsedOutput := by
  exact And.intro
    (by simp [LangChainBefore, LangChainRank])
    (And.intro
      (by simp [LangChainBefore, LangChainRank])
      (And.intro
        (by simp [LangChainBefore, LangChainRank])
        (by simp [LangChainBefore, LangChainRank])))

theorem langchain_ui_no_implicit_tool_branch :
    Not (LangChainDependsOn .parsedOutput .model) := by
  intro h
  simp [LangChainDependsOn] at h

theorem langchain_ui_case_complete :
    LangChainBefore .memory .prompt /\
      LangChainBefore .prompt .model /\
      LangChainBefore .model .parser /\
      LangChainBefore .parser .parsedOutput /\
      Not (LangChainDependsOn .parsedOutput .model) := by
  exact And.intro
    (by simp [LangChainBefore, LangChainRank])
    (And.intro
      (by simp [LangChainBefore, LangChainRank])
      (And.intro
        (by simp [LangChainBefore, LangChainRank])
        (And.intro
          (by simp [LangChainBefore, LangChainRank])
          langchain_ui_no_implicit_tool_branch)))

inductive LangGraphNode where
  | session
  | state
  | router
  | agentNode
  | toolNode
  | terminal
  | runtimeHandoff
deriving Repr, DecidableEq

inductive LangGraphEdgeKind where
  | normal
  | conditional
  | loop
deriving Repr, DecidableEq

def LangGraphDeclared (_node : LangGraphNode) : Prop :=
  True

def LangGraphEdge :
    LangGraphNode -> LangGraphNode -> LangGraphEdgeKind -> Prop
  | .session, .state, .normal => True
  | .state, .router, .normal => True
  | .router, .agentNode, .conditional => True
  | .agentNode, .router, .loop => True
  | .router, .toolNode, .conditional => True
  | .toolNode, .router, .loop => True
  | .router, .terminal, .conditional => True
  | .terminal, .runtimeHandoff, .normal => True
  | _, _, _ => False

inductive LangGraphCanReachHandoff : LangGraphNode -> Prop where
  | fromRuntime :
      LangGraphCanReachHandoff .runtimeHandoff
  | fromTerminal :
      LangGraphCanReachHandoff .terminal
  | fromRouter :
      LangGraphCanReachHandoff .router
  | fromAgentNode :
      LangGraphCanReachHandoff .agentNode
  | fromToolNode :
      LangGraphCanReachHandoff .toolNode
  | fromState :
      LangGraphCanReachHandoff .state
  | fromSession :
      LangGraphCanReachHandoff .session

theorem langgraph_ui_conditional_targets_declared :
    forall fromNode toNode,
      LangGraphEdge fromNode toNode .conditional ->
        LangGraphDeclared toNode := by
  intro _ _ _
  trivial

theorem langgraph_ui_loop_edges_explicit :
    forall fromNode toNode,
      LangGraphEdge fromNode toNode .loop ->
        (fromNode = .agentNode /\ toNode = .router) \/
          (fromNode = .toolNode /\ toNode = .router) := by
  intro fromNode toNode h
  cases fromNode <;> cases toNode <;>
    simp [LangGraphEdge] at h ⊢

theorem langgraph_ui_finish_total :
    forall node,
      LangGraphDeclared node ->
        LangGraphCanReachHandoff node := by
  intro node _
  cases node
  · exact LangGraphCanReachHandoff.fromSession
  · exact LangGraphCanReachHandoff.fromState
  · exact LangGraphCanReachHandoff.fromRouter
  · exact LangGraphCanReachHandoff.fromAgentNode
  · exact LangGraphCanReachHandoff.fromToolNode
  · exact LangGraphCanReachHandoff.fromTerminal
  · exact LangGraphCanReachHandoff.fromRuntime

structure LangGraphLoopProgress where
  fromNode : LangGraphNode
  toNode : LangGraphNode
  fuelBefore : Nat
  fuelAfter : Nat
  edgeIsLoop : LangGraphEdge fromNode toNode .loop
  fuelDecreases : fuelAfter < fuelBefore

theorem langgraph_ui_loop_progress_not_zero
    (progress : LangGraphLoopProgress) :
    progress.fuelBefore ≠ 0 := by
  intro hzero
  exact (Nat.not_lt_zero progress.fuelAfter)
    (by simpa [hzero] using progress.fuelDecreases)

inductive LangGraphBranchTarget where
  | declared : LangGraphNode -> LangGraphBranchTarget
  | missingNode
deriving Repr

def LangGraphBranchTargetDeclared : LangGraphBranchTarget -> Prop
  | .declared _ => True
  | .missingNode => False

theorem langgraph_missing_branch_target_rejected :
    Not (LangGraphBranchTargetDeclared .missingNode) := by
  intro h
  exact h

theorem langgraph_ui_case_complete :
    LangGraphCanReachHandoff .session /\
      LangGraphCanReachHandoff .runtimeHandoff /\
      (forall fromNode toNode,
        LangGraphEdge fromNode toNode .conditional ->
          LangGraphDeclared toNode) /\
      (forall fromNode toNode,
        LangGraphEdge fromNode toNode .loop ->
          (fromNode = .agentNode /\ toNode = .router) \/
            (fromNode = .toolNode /\ toNode = .router)) := by
  exact And.intro LangGraphCanReachHandoff.fromSession
    (And.intro LangGraphCanReachHandoff.fromRuntime
      (And.intro langgraph_ui_conditional_targets_declared
        langgraph_ui_loop_edges_explicit))

structure ProductionRuntimeFacts where
  runtimeExecuted : Prop
  finished : Prop
  loopFuelContained : Prop
  handoffReached : Prop
  sandboxScopeContained : Prop
  toolPermissionsContained : Prop
  checkpointPersisted : Prop
  humanApprovalSound : Prop
  subagentsParented : Prop
  diagnosticsEmpty : Prop

def ReusableProductionRuntime
    (facts : ProductionRuntimeFacts) : Prop :=
  facts.runtimeExecuted ∧
  facts.finished ∧
  facts.loopFuelContained ∧
  facts.handoffReached ∧
  facts.sandboxScopeContained ∧
  facts.toolPermissionsContained ∧
  facts.checkpointPersisted ∧
  facts.humanApprovalSound ∧
  facts.subagentsParented ∧
  facts.diagnosticsEmpty

theorem production_runtime_has_checkpoint_and_human_gate
    {facts : ProductionRuntimeFacts}
    (h : ReusableProductionRuntime facts) :
    facts.checkpointPersisted /\ facts.humanApprovalSound := by
  exact And.intro h.right.right.right.right.right.right.left
    h.right.right.right.right.right.right.right.left

theorem production_runtime_has_scope_and_tool_containment
    {facts : ProductionRuntimeFacts}
    (h : ReusableProductionRuntime facts) :
    facts.sandboxScopeContained /\ facts.toolPermissionsContained := by
  exact And.intro h.right.right.right.right.left
    h.right.right.right.right.right.left

theorem missing_human_approval_rejects_production_runtime
    {facts : ProductionRuntimeFacts}
    (missing : Not facts.humanApprovalSound) :
    Not (ReusableProductionRuntime facts) := by
  intro h
  exact missing h.right.right.right.right.right.right.right.left

theorem open_diagnostics_reject_production_runtime
    {facts : ProductionRuntimeFacts}
    (openDiagnostics : Not facts.diagnosticsEmpty) :
    Not (ReusableProductionRuntime facts) := by
  intro h
  exact openDiagnostics
    h.right.right.right.right.right.right.right.right.right

structure LanePolicyFacts
    (Lane : Type u1)
    (Scope : Type u2)
    (Tool : Type u3) where
  laneScope : Lane -> Scope
  parentScope : Lane -> Scope
  requestedTool : Lane -> Tool -> Prop
  toolAllowedInLane : Lane -> Tool -> Prop
  scopeContained : Lane -> Prop
  toolsContained : Lane -> Prop

structure SoundLanePolicy
    {Lane : Type u1}
    {Scope : Type u2}
    {Tool : Type u3}
    (facts : LanePolicyFacts Lane Scope Tool) : Prop where
  scopeSound :
    forall lane,
      facts.scopeContained lane
  toolSound :
    forall lane tool,
      facts.requestedTool lane tool ->
        facts.toolAllowedInLane lane tool
  toolsSound :
    forall lane,
      facts.toolsContained lane

theorem reusable_lane_has_scope_and_tool_containment
    {Lane : Type u1}
    {Scope : Type u2}
    {Tool : Type u3}
    {facts : LanePolicyFacts Lane Scope Tool}
    (h : SoundLanePolicy facts)
    {lane : Lane} :
    facts.scopeContained lane /\ facts.toolsContained lane := by
  exact And.intro (h.scopeSound lane) (h.toolsSound lane)

theorem requested_tool_overflow_contradicts_lane_soundness
    {Lane : Type u1}
    {Scope : Type u2}
    {Tool : Type u3}
    {facts : LanePolicyFacts Lane Scope Tool}
    (h : SoundLanePolicy facts)
    {lane : Lane}
    {tool : Tool}
    (hrequest : facts.requestedTool lane tool)
    (hoverflow : Not (facts.toolAllowedInLane lane tool)) :
    False := by
  exact hoverflow (h.toolSound lane tool hrequest)

end AgenticAILabProof.PooC4.LangChainLangGraph
