import AgenticAILabSessionProof.Lifecycle
import AgenticAILabSessionProof.SharedContext
import AgenticAILabSessionProof.OrgMemory
import AgenticAILabSessionProof.PolicyC4
import Lean.Util.CollectAxioms
import Lean.Elab.Command

open Lean Elab Command

/- Audit the Agentic AI Lab Session model and imported C4 certificates together. -/
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  for required in #[
      `AgenticAILabSessionProof.Lifecycle.closed_session_cannot_begin,
      `AgenticAILabSessionProof.Lifecycle.accepted_query_use_has_exact_session_turn_cut,
      `AgenticAILabSessionProof.SharedContext.authorized_tasks_share_current_worktree_head,
      `AgenticAILabSessionProof.SharedContext.accepted_transfer_advances_only_target,
      `AgenticAILabSessionProof.OrgMemory.accepted_selection_preserves_source_without_publication,
      `AgenticAILabSessionProof.OrgMemory.changed_bytes_refused,
      `AgenticAILabSessionProof.PolicyC4.member_requires_graph_ancestry] do
    unless environment.contains required do
      throwError "Required Session theorem was not loaded: {required}"
  let mut count : Nat := 0
  let mut c4Count : Nat := 0
  for (name, _) in environment.constants.toList do
    if (`AgenticAILabSessionProof).isPrefixOf name || (`LeanPoo.C4).isPrefixOf name then
      count := count + 1
      if (`LeanPoo.C4).isPrefixOf name then c4Count := c4Count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do
          throwError "{name} depends on disallowed axiom {axiomName}"
  if c4Count = 0 then throwError "LeanPoo C4 certificates were not loaded"
  logInfo m!"SESSION-AXIOM-AUDIT-OK: {count} declarations ({c4Count} LeanPoo C4); standard Lean axioms only"
