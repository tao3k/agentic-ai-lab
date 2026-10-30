-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import LeanPoo.Proof.Invalidation

/-!
The temporal module's proof-reuse boundary. A cut revision is a LeanPoo
patch over subject/conclusion keys. LeanPoo's proof object carries the exact
dependency list for each conclusion obligation. This does not prove the Scheme
reverse index implementation or establish causal truth.
-/

namespace AgenticAILabTemporalPooProof.TruthMaintenance

open LeanPoo.Proof

inductive PremiseKey where
  | subject (identity : String)
  | conclusion (identity : String)
  deriving DecidableEq, Repr

/-- The POO proof object retains all old obligations and their certificate. -/
structure CertifiedCut where
  cutIdentity : String
  object : ProofObject PremiseKey (fun _ => Bool)
  certificate : Certificate object

/-- An explicit cut revision changes the premise footprint in a LeanPoo patch. -/
structure CutRevision where
  previousCut : String
  revisedCut : String
  changed : List PremiseKey
  patch : Patch PremiseKey (fun _ => Bool)
  footprint : patch.touched = changed

/-- Every changed dependency of an old obligation is selected by `pending`. -/
theorem changedPremiseSchedules
    (cut : CertifiedCut) (revision : CutRevision)
    (obligation : Obligation PremiseKey (fun _ => Bool))
    (owned : obligation ∈ cut.object.obligations)
    (key : PremiseKey)
    (depends : key ∈ obligation.dependencies)
    (changed : key ∈ revision.changed) :
    obligation ∈ pending cut.object revision.patch := by
  apply List.mem_append.mpr
  left
  apply List.mem_filter.mpr
  refine ⟨owned, ?_⟩
  have member : key ∈ changedDependencies obligation revision.patch := by
    simp [changedDependencies, depends, revision.footprint, changed]
  cases h : changedDependencies obligation revision.patch with
  | nil => simp [h] at member
  | cons _ _ => simp

/-- An old obligation whose dependencies are outside the patch footprint is
not scheduled unless the patch explicitly introduces it as a new obligation. -/
theorem unaffectedPremiseNotScheduled
    (cut : CertifiedCut) (revision : CutRevision)
    (obligation : Obligation PremiseKey (fun _ => Bool))
    (safe : unaffected obligation revision.patch)
    (notAdded : obligation ∉ revision.patch.obligations) :
    obligation ∉ pending cut.object revision.patch := by
  intro scheduled
  rcases (mem_pending_iff cut.object revision.patch obligation).mp scheduled with
    ⟨_, affected⟩ | added
  · exact affected safe
  · exact notAdded added

/-- If new proofs discharge the selected frontier, the revised POO object
has a certificate while old unaffected obligations are reused by LeanPoo. -/
theorem revisedCutCertified
    (cut : CertifiedCut) (revision : CutRevision)
    (_matching : cut.cutIdentity = revision.previousCut)
    (discharged : ∀ obligation,
      obligation ∈ pending cut.object revision.patch →
        obligation.holds (append cut.object revision.patch).state) :
    Certificate (append cut.object revision.patch) := by
  exact closePending cut.object revision.patch cut.certificate discharged

end AgenticAILabTemporalPooProof.TruthMaintenance
