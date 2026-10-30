/- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
   SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later -/
import Lean
namespace AgenticAILabOrgAnchorProof
-- The parser owns rows; this law projects unique source lookup and selected ownership.
-- Natural-number cuts/scopes abstract exact native binding records, not hash injectivity.
structure Anchor where
  id : Nat
  owner : Nat
  start : Nat
  finish : Nat
  deriving DecidableEq
structure Binding where
  anchor : Anchor
  sourceCut : Nat
  consumerScope : Nat
  deriving DecidableEq

def matching (rows : List Anchor) (id : Nat) := rows.filter (fun a => a.id == id)
def admit (rows : List Anchor) (id : Nat) (candidate : Anchor) (selected : List Nat)
    (expectedSource actualSource expectedScope actualScope : Nat) : Option Binding :=
  if matching rows id = [candidate] ∧ candidate.id = id ∧ candidate.owner ∈ selected ∧
      candidate.start < candidate.finish ∧ expectedSource = actualSource ∧ expectedScope = actualScope
  then some ⟨candidate, actualSource, actualScope⟩ else none

theorem accepted_has_exact_source_lookup (rows : List Anchor) (id : Nat)
    (candidate : Anchor) (selected : List Nat) (es as ep ap : Nat) (result : Binding)
    (accepted : admit rows id candidate selected es as ep ap = some result) :
    matching rows id = [candidate] ∧ candidate.id = id ∧ candidate.owner ∈ selected ∧
      candidate.start < candidate.finish ∧ es = as ∧ ep = ap := by
  unfold admit at accepted
  split at accepted
  · assumption
  · simp at accepted

theorem accepted_reconstructs_current_binding (rows : List Anchor) (id : Nat)
    (candidate : Anchor) (selected : List Nat) (es as ep ap : Nat) (result : Binding)
    (accepted : admit rows id candidate selected es as ep ap = some result) :
    result = ⟨candidate, as, ap⟩ := by
  unfold admit at accepted
  split at accepted
  · simpa using accepted.symm
  · simp at accepted

theorem wrong_source_refused (rows : List Anchor) (id : Nat) (candidate : Anchor)
    (selected : List Nat) (es as ep ap : Nat) (wrong : es ≠ as) :
    admit rows id candidate selected es as ep ap = none := by simp [admit, wrong]
theorem wrong_scope_refused (rows : List Anchor) (id : Nat) (candidate : Anchor)
    (selected : List Nat) (es as ep ap : Nat) (wrong : ep ≠ ap) :
    admit rows id candidate selected es as ep ap = none := by simp [admit, wrong]
theorem unselected_owner_refused (rows : List Anchor) (id : Nat) (candidate : Anchor)
    (selected : List Nat) (es as ep ap : Nat) (outside : candidate.owner ∉ selected) :
    admit rows id candidate selected es as ep ap = none := by simp [admit, outside]
theorem invalid_span_refused (rows : List Anchor) (id : Nat) (candidate : Anchor)
    (selected : List Nat) (es as ep ap : Nat) (wrong : ¬candidate.start < candidate.finish) :
    admit rows id candidate selected es as ep ap = none := by simp [admit, wrong]
theorem ambiguous_lookup_refused (rows : List Anchor) (id : Nat) (candidate : Anchor)
    (selected : List Nat) (es as ep ap : Nat) (ambiguous : (matching rows id).length ≠ 1) :
    admit rows id candidate selected es as ep ap = none := by
  have different : matching rows id ≠ [candidate] := by
    intro equality
    apply ambiguous
    simp [equality]
  simp [admit, different]
end AgenticAILabOrgAnchorProof

open Lean Elab Command in
run_cmd do
  let environment ← getEnv
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  let mut count : Nat := 0
  for (name, info) in environment.constants.toList do
    if (`AgenticAILabOrgAnchorProof).isPrefixOf name then
      if info.isTheorem then count := count + 1
      for axiomName in (← collectAxioms name) do
        unless allowed.contains axiomName do throwError "Disallowed anchor axiom: {axiomName}"
  for required in #[`AgenticAILabOrgAnchorProof.accepted_has_exact_source_lookup,
      `AgenticAILabOrgAnchorProof.accepted_reconstructs_current_binding,
      `AgenticAILabOrgAnchorProof.wrong_source_refused, `AgenticAILabOrgAnchorProof.wrong_scope_refused,
      `AgenticAILabOrgAnchorProof.unselected_owner_refused, `AgenticAILabOrgAnchorProof.invalid_span_refused,
      `AgenticAILabOrgAnchorProof.ambiguous_lookup_refused] do
    unless environment.contains required do throwError "Missing anchor theorem: {required}"
  logInfo m!"ORG-ANCHOR-AXIOM-AUDIT-OK: {count} theorems; standard Lean axioms only"
