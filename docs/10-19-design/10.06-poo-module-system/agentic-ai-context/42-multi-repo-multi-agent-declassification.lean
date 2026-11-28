-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/-!
Slice 42 — Lean Unbounded Redaction Projection & Set-Algebra Laws ONLY:
Per `FormalVerificationTaxonomy` in `42-multi-repo-multi-agent-declassification.sysml`,
this module proves pure algebraic and inductive laws over unbounded field lists
and reader predicates:
1. Pure redaction operator `redactFields` idempotence (`redactFields_idem`),
   active-defeater preservation (`redactFields_preserves_defeaters`), complete
   secret stripping (`redactFields_strips_all_secrets`), and length contraction
   (`redactFields_length_le`).
2. Structural non-collision (`redacted_ne_raw_when_secret_present` and
   `commit_redacted_ne_raw` under injective commitments) so a redacted digest
   can never alias raw secret-bearing content.
3. Set-intersection impossibility (`ordinary_intersection_never_adds_ungranted_subagent`).
Multi-actor certificate signing, transitive subagent spawning, and origin-cut
cascade races belong exclusively to `42-*.qnt`.
-/

namespace MultiRepoAgentDeclassification

inductive FieldSensitivity where
  | publicFact
  | activeDefeater
  | restrictedSecret
  deriving DecidableEq, Repr

structure OrgField (Payload : Type) where
  sensitivity : FieldSensitivity
  payload : Payload
  deriving DecidableEq, Repr

def keepAfterRedaction {Payload : Type} (f : OrgField Payload) : Bool :=
  f.sensitivity != .restrictedSecret

def redactFields {Payload : Type} (xs : List (OrgField Payload)) : List (OrgField Payload) :=
  xs.filter keepAfterRedaction

theorem redactFields_idem {Payload : Type} (xs : List (OrgField Payload)) :
    redactFields (redactFields xs) = redactFields xs := by
  induction xs with
  | nil => rfl
  | cons head tail ih =>
      unfold redactFields
      rw [List.filter_cons]
      split
      · rename_i hKeep
        simp only [List.filter_cons, hKeep, ↓reduceIte]
        exact congrArg (head :: ·) ih
      · exact ih

theorem redactFields_preserves_defeaters {Payload : Type}
    (xs : List (OrgField Payload)) (d : OrgField Payload)
    (hMem : d ∈ xs)
    (hDef : d.sensitivity = .activeDefeater) :
    d ∈ redactFields xs := by
  unfold redactFields
  rw [List.mem_filter]
  refine ⟨hMem, ?_⟩
  unfold keepAfterRedaction
  rw [hDef]
  rfl

theorem redactFields_strips_all_secrets {Payload : Type}
    (xs : List (OrgField Payload)) (f : OrgField Payload)
    (hMem : f ∈ redactFields xs) :
    f.sensitivity ≠ .restrictedSecret := by
  unfold redactFields at hMem
  rw [List.mem_filter] at hMem
  unfold keepAfterRedaction at hMem
  exact bne_iff_ne.mp hMem.2

theorem redactFields_length_le {Payload : Type} (xs : List (OrgField Payload)) :
    (redactFields xs).length ≤ xs.length :=
  List.length_filter_le _ _

theorem redacted_ne_raw_when_secret_present {Payload : Type}
    (xs : List (OrgField Payload)) (s : OrgField Payload)
    (hSecretInRaw : s ∈ xs)
    (hIsSecret : s.sensitivity = .restrictedSecret) :
    redactFields xs ≠ xs := by
  intro hEq
  have hInRedacted : s ∈ redactFields xs := by
    rw [hEq]
    exact hSecretInRaw
  exact (redactFields_strips_all_secrets xs s hInRedacted) hIsSecret

theorem commit_redacted_ne_raw {Payload Digest : Type}
    (commit : List (OrgField Payload) → Digest)
    (hInj : ∀ a b, commit a = commit b → a = b)
    (xs : List (OrgField Payload)) (s : OrgField Payload)
    (hSecretInRaw : s ∈ xs)
    (hIsSecret : s.sensitivity = .restrictedSecret) :
    commit (redactFields xs) ≠ commit xs := by
  intro hCommitEq
  exact redacted_ne_raw_when_secret_present xs s hSecretInRaw hIsSecret (hInj _ _ hCommitEq)

/-! ## Reader-Set Intersection Algebra -/

def intersectReaders {Agent : Type} (r1 r2 : Agent → Prop) : Agent → Prop :=
  fun a => r1 a ∧ r2 a

theorem intersectReaders_comm {Agent : Type} (r1 r2 : Agent → Prop) (a : Agent) :
    intersectReaders r1 r2 a ↔ intersectReaders r2 r1 a :=
  And.comm

theorem ordinary_intersection_never_adds_ungranted_subagent
    {Agent : Type} (originReaders targetReaders : Agent → Prop) (subagent : Agent)
    (hDeniedAtOrigin : ¬ originReaders subagent) :
    ¬ intersectReaders originReaders targetReaders subagent :=
  fun hBoth => hDeniedAtOrigin hBoth.1

end MultiRepoAgentDeclassification
