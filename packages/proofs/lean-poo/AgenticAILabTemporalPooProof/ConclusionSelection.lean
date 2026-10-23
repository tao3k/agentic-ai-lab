-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabTemporalPooProof.TruthMaintenance

/-!
An abstract versioned selection law. The temporal runtime still owns the
atomic compare-and-swap, capability check and durable pointer receipt.
-/

namespace AgenticAILabTemporalPooProof.ConclusionSelection

structure Pointer where
  version : Nat
  selected : String
  deriving DecidableEq, Repr

structure Proposal where
  predecessor : String
  successor : String
  expectedVersion : Nat
  deriving DecidableEq, Repr

def Ready (pointer : Pointer) (proposal : Proposal) : Prop :=
  pointer.version = proposal.expectedVersion ∧
    pointer.selected = proposal.predecessor

def commit (pointer : Pointer) (proposal : Proposal)
    (_ready : Ready pointer proposal) : Pointer :=
  { version := pointer.version + 1, selected := proposal.successor }

/-- A second proposal against the old version cannot pass the version check
after one abstract atomic commit, regardless of its proposed successor. -/
theorem competingOldVersionIsStale
    (pointer : Pointer) (first second : Proposal)
    (firstReady : Ready pointer first)
    (sameExpected : second.expectedVersion = first.expectedVersion) :
    ¬ Ready (commit pointer first firstReady) second := by
  intro secondReady
  have oldVersion : pointer.version = first.expectedVersion := firstReady.1
  have newVersion : pointer.version + 1 = second.expectedVersion :=
    secondReady.1
  have impossible : pointer.version + 1 = pointer.version := by
    calc
      pointer.version + 1 = second.expectedVersion := newVersion
      _ = first.expectedVersion := sameExpected
      _ = pointer.version := oldVersion.symm
  exact Nat.succ_ne_self pointer.version impossible

end AgenticAILabTemporalPooProof.ConclusionSelection
