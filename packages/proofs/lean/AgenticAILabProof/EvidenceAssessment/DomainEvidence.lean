-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import Lean
namespace AgenticAILabProof.DomainEvidence
-- Arithmetic contracts over observed integers, not arbitrary Python semantics.
def GraphUpdate (expected observed before removed after : Int) : Prop :=
  expected = observed ∧ after = before - removed ∧ removed ≤ before
theorem checked_update_conserves (h : GraphUpdate expected observed before removed after) :
    after + removed = before ∧ 0 ≤ after ∧ expected = observed := by
  rcases h with ⟨hv, ha, hn⟩
  constructor
  · omega
  · exact ⟨by omega, hv⟩
-- Rational internal precision i/d: cross-multiply by a nonzero root order.
def PrecisionBudget (m n p i d : Int) : Prop := i*n = (p*n-m)*d
theorem restored_precision (h : PrecisionBudget m n p i d) :
    i*n + m*d = (p*n)*d := by
  unfold PrecisionBudget at h
  rw [Int.sub_mul] at h
  omega
-- All rational numerators/denominators, after exact cross multiplication.
def RationalBudget (m md n p pd i d : Int) : Prop :=
  i*n*pd*md = (p*n*md-m*pd)*d
theorem restored_rational_precision (h : RationalBudget m md n p pd i d) :
    i*n*pd*md + (m*pd)*d = (p*n*md)*d := by
  unfold RationalBudget at h
  rw [Int.sub_mul] at h
  omega
def RationalKeep (m md n p pd e ed : Int) : Prop :=
  if n > 0 then e*n*md*pd + m*ed*pd < p*n*ed*md
  else e*n*md*pd + m*ed*pd > p*n*ed*md
theorem rational_boundary_excluded
    (h : e*n*md*pd + m*ed*pd = p*n*ed*md) :
    ¬ RationalKeep m md n p pd e ed := by
  unfold RationalKeep
  split <;> omega
def KeepTerm (m n p e : Int) : Prop :=
  if n > 0 then e*n+m < p*n else e*n+m > p*n
instance : Decidable (KeepTerm m n p e) := by unfold KeepTerm; infer_instance
theorem boundary_excluded (_hn : n ≠ 0) (h : e*n+m = p*n) :
    ¬ KeepTerm m n p e := by
  unfold KeepTerm
  split <;> omega
def Admit (snapshot cachedSnapshot checker cachedChecker : Nat) : Prop :=
  snapshot = cachedSnapshot ∧ checker = cachedChecker
theorem snapshot_change_invalidates (h : snapshot ≠ cachedSnapshot) :
    ¬ Admit snapshot cachedSnapshot checker cachedChecker := fun a => h a.1
theorem checker_change_invalidates (h : checker ≠ cachedChecker) :
    ¬ Admit snapshot cachedSnapshot checker cachedChecker := fun a => h a.2
-- A selected-grader artifact additionally binds the bytes actually copied.
def SealedCandidate (current graded copied grader expectedGrader : Nat) : Prop :=
  current = graded ∧ current = copied ∧ grader = expectedGrader
theorem stale_candidate_cannot_seal (h : current ≠ graded) :
    ¬ SealedCandidate current graded copied grader expectedGrader := fun a => h a.1
theorem changed_bytes_cannot_seal (h : current ≠ copied) :
    ¬ SealedCandidate current graded copied grader expectedGrader := fun a => h a.2.1
theorem changed_grader_cannot_seal (h : grader ≠ expectedGrader) :
    ¬ SealedCandidate current graded copied grader expectedGrader := fun a => h a.2.2
def MayEdit (sealed : Bool) : Prop := sealed = false
theorem sealed_rejects_edit : ¬ MayEdit true := by simp [MayEdit]
theorem coherent_membership (group eligible : List Int) (observed : List Int)
    (h : observed = group.filter (fun n => eligible.contains n)) (hn : node ∈ observed) :
    node ∈ group ∧ node ∈ eligible := by
  rw [h] at hn
  simpa using hn
-- 2400 exact precision cases, including negative roots and equality boundaries.
def precisionCases : List (List Int) :=
  [-2,-1,0,1,2].flatMap fun m => [-2,-1,1,2].flatMap fun n =>
  [0,1,2,3].flatMap fun p => [-2,-1,0,1,2].flatMap fun e =>
  [-1,0,1].flatMap fun delta => [0,1].map fun included =>
    let keep := decide (KeepTerm m n p e)
    [m,n,p,e,delta,included, if delta = 0 then 1 else 0,
     if (included == 1) == keep then 1 else 0]
def graphCases : List (List Int) :=
  [0,1].flatMap fun expected => [0,1].flatMap fun observed =>
  [0,1,2,3,4].flatMap fun before => [0,1,2,3,4].flatMap fun removed =>
  [0,1,2,3,4].map fun after =>
    [expected,observed,before,removed,after,
     if expected = observed then 1 else 0,
     if after = before-removed then 1 else 0, if removed ≤ before then 1 else 0]
def main (args : List String) : IO Unit := do
  for path in args do
    let parsed ← match Lean.Json.parse (← IO.FS.readFile path) with
      | .ok x => pure x
      | .error e => throw (IO.userError e)
    let expected := if path.endsWith "graph.json" then graphCases else precisionCases
    unless parsed == Lean.toJson expected do throw (IO.userError s!"domain correspondence differs: {path}")
  IO.println "DOMAIN-EVIDENCE-LEAN-OK precisionCases=2400 graphCases=500"
end AgenticAILabProof.DomainEvidence
def main := AgenticAILabProof.DomainEvidence.main
