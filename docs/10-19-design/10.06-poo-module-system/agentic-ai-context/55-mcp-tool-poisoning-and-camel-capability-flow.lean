-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
  Slice 55: MCP Tool Poisoning, Post-Approval Rug-Pull Manifest Pinning,
  Cross-Server Tool Shadowing Isolation, CaMeL Capability-Provenance Flow,
  and MindGuard Zero-LLM Decision-Dependence Auditing.
-/

namespace McpToolPoisoningAndCamelCapabilityFlow

-- ===========================================================================
-- 1. Cryptographic Tool Manifest Pinning (Anti-Rug-Pull, MCPTox)
-- ===========================================================================

structure ToolManifest where
  serverId : Nat
  toolId : Nat
  descriptionDigest : Nat
  schemaDigest : Nat
  deriving DecidableEq, Repr

def manifestPinMatches (pinned live : ToolManifest) : Bool :=
  decide (pinned = live)

theorem rugPullMutation_breaks_manifest_pin
    (pinned live : ToolManifest)
    (hSameId : pinned.serverId = live.serverId ∧ pinned.toolId = live.toolId)
    (hDrift : pinned.descriptionDigest ≠ live.descriptionDigest ∨
              pinned.schemaDigest ≠ live.schemaDigest) :
    manifestPinMatches pinned live = false := by
  have hne : pinned ≠ live := by
    intro heq
    subst heq
    rcases hDrift with h | h <;> exact h rfl
  simp [manifestPinMatches, hne]

-- ===========================================================================
-- 2. Cross-Server Tool Shadowing Rejection & Metadata Segregation
-- ===========================================================================

structure RegisteredTool where
  serverId : Nat
  toolId : Nat
  deriving DecidableEq, Repr

/-- Registering `(serverId, toolId)` fails closed if any existing entry owns
    `toolId` under a different `serverId`. -/
def admitToolRegistration (registry : List RegisteredTool) (cand : RegisteredTool) : Bool :=
  registry.all (fun e => decide (e.toolId ≠ cand.toolId ∨ e.serverId = cand.serverId))

theorem crossServerShadowing_rejected_fail_closed
    (registry : List RegisteredTool)
    (existing cand : RegisteredTool)
    (hMem : existing ∈ registry)
    (hSameTool : existing.toolId = cand.toolId)
    (hDiffServer : existing.serverId ≠ cand.serverId) :
    admitToolRegistration registry cand = false := by
  unfold admitToolRegistration
  induction registry with
  | nil => cases hMem
  | cons hd tl ih =>
    cases hMem with
    | head =>
      simp [hSameTool, hDiffServer]
    | tail _ hIn =>
      rw [List.all_cons, ih hIn, Bool.and_false]

inductive TrustTier where
  | untrustedMetadata
  | rawToolOutput
  | observedFact
  | userIntent
  | systemPolicy
  deriving DecidableEq, Repr

def trustTierRank : TrustTier → Nat
  | .untrustedMetadata => 0
  | .rawToolOutput => 1
  | .observedFact => 2
  | .userIntent => 3
  | .systemPolicy => 4

/-- Tool descriptions from external servers are permanently assigned to
    `untrustedMetadata` (rank 0 < `userIntent` rank 3). -/
def classifyExternalToolDescription (_descDigest : Nat) : TrustTier :=
  .untrustedMetadata

theorem metadataSegregation_keeps_description_untrusted (descDigest : Nat) :
    trustTierRank (classifyExternalToolDescription descDigest) < trustTierRank .userIntent := by
  simp [classifyExternalToolDescription, trustTierRank]

-- ===========================================================================
-- 3. CaMeL Value-Level Capability Provenance & Sensitive Sink Gate
-- ===========================================================================

inductive SinkSensitivity where
  | benign
  | sensitive
  deriving DecidableEq, Repr

structure SinkInvocationCheck where
  sink : SinkSensitivity
  argOrigin : TrustTier
  manifestPinned : Bool
  hasDeclassCert : Bool
  deriving DecidableEq, Repr

def isUntrustedOrigin : TrustTier → Bool
  | .untrustedMetadata => true
  | .rawToolOutput => true
  | _ => false

/-- CaMeL sink policy: sensitive sinks refuse untrusted-origin arguments unless
    backed by an explicit active 3-party declassification certificate, and every
    invocation requires a matching manifest pin. -/
def admitSinkInvocation (c : SinkInvocationCheck) : Bool :=
  c.manifestPinned &&
  match c.sink with
  | .benign => true
  | .sensitive => !isUntrustedOrigin c.argOrigin || c.hasDeclassCert

theorem untrustedOriginArgument_blocked_at_sensitive_sink
    (c : SinkInvocationCheck)
    (hsens : c.sink = .sensitive)
    (huntrust : isUntrustedOrigin c.argOrigin = true)
    (hnocert : c.hasDeclassCert = false) :
    admitSinkInvocation c = false := by
  simp [admitSinkInvocation, hsens, huntrust, hnocert]

theorem userIntentArgument_admitted_at_sensitive_sink
    (c : SinkInvocationCheck)
    (hpin : c.manifestPinned = true)
    (horigin : c.argOrigin = .userIntent) :
    admitSinkInvocation c = true := by
  cases hs : c.sink <;> simp [admitSinkInvocation, hpin, horigin, isUntrustedOrigin, hs]

-- ===========================================================================
-- 4. MindGuard Zero-LLM Counterfactual Decision-Dependence Audit
-- ===========================================================================

structure DecisionDependenceAuditResult where
  decisionFlipped : Bool
  hijackFlagged : Bool
  llmCallsUsed : Nat
  deriving DecidableEq, Repr

def auditToolMetadataDecisionDependence
    (toolWithMetadata toolWithoutMetadata : Nat)
    (metadataEndorsed : Bool) : DecisionDependenceAuditResult :=
  let flipped := decide (toolWithMetadata ≠ toolWithoutMetadata)
  { decisionFlipped := flipped
  , hijackFlagged := flipped && !metadataEndorsed
  , llmCallsUsed := 0
  }

theorem decisionDependenceAudit_flags_unendorsed_metadata_hijack
    (withMeta withoutMeta : Nat)
    (hFlip : withMeta ≠ withoutMeta) :
    let res := auditToolMetadataDecisionDependence withMeta withoutMeta false
    res.decisionFlipped = true ∧ res.hijackFlagged = true ∧ res.llmCallsUsed = 0 := by
  simp [auditToolMetadataDecisionDependence, hFlip]

end McpToolPoisoningAndCamelCapabilityFlow
