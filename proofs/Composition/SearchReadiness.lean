-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchAttempt
namespace POO.Flow.SearchReadiness
open POO.Flow.SearchAttempt
def quintSourceDigest : String := "sha256:98e48d9eff9ba945e51201008a44fb25c08069bcf4233546158ec2b104cabf91"
def quintInvariantNames : List String := ["AllPrerequisites", "CurrentPrerequisites", "ScopeIsolation"]

/-- Completion identities have already passed settlement admission at their owner. -/
def complete (state : State) (request : Request) : Option (State × Request) :=
  (settle state request).map (fun next => (next, request))

/-- The DAG owner supplies current predecessor identities; membership is exact. -/
def Ready (state : State) (prerequisites completed : List Request) : Prop :=
  ∀ request ∈ prerequisites, request ∈ completed ∧
    request.scope.generation = state.scope.generation ∧
    request.scope.configuration = state.scope.configuration

instance (state : State) (prerequisites completed : List Request) :
    Decidable (Ready state prerequisites completed) :=
  inferInstanceAs (Decidable (∀ request ∈ prerequisites, request ∈ completed ∧
    request.scope.generation = state.scope.generation ∧
    request.scope.configuration = state.scope.configuration))

def issueReady (state : State) (prerequisites completed : List Request) :=
  if Ready state prerequisites completed then issue state else none

theorem completion_admitted {state next : State} {request : Request}
    (accepted : complete state request = some (next, request)) : Admits state request := by
  unfold complete at accepted
  cases h : settle state request with
  | none => simp [h] at accepted
  | some done => exact settlement_exact h

theorem issued_prerequisites {state next : State} {request : Request}
    {prerequisites completed : List Request}
    (issued : issueReady state prerequisites completed = some (next, request)) :
    Ready state prerequisites completed := by
  unfold issueReady at issued
  split at issued
  · assumption
  · contradiction

theorem missing_blocks (state : State) (prerequisites completed : List Request)
    (request : Request) (required : request ∈ prerequisites)
    (missing : request ∉ completed) : issueReady state prerequisites completed = none := by
  have blocked : ¬ Ready state prerequisites completed := fun ready => missing (ready request required).1
  simp [issueReady, blocked]

theorem scope_blocks (state : State) (prerequisites completed : List Request)
    (request : Request) (required : request ∈ prerequisites)
    (foreign : request.scope.generation ≠ state.scope.generation ∨
      request.scope.configuration ≠ state.scope.configuration) :
    issueReady state prerequisites completed = none := by
  have blocked : ¬ Ready state prerequisites completed := by
    intro ready
    rcases foreign with gen | config
    · exact gen (ready request required).2.1
    · exact config (ready request required).2.2
  simp [issueReady, blocked]

theorem root_ready (state : State) (completed : List Request) : Ready state [] completed := by
  simp [Ready]

theorem ready_preserves_attempt_gate {state next : State} {request : Request}
    {prerequisites completed : List Request}
    (issued : issueReady state prerequisites completed = some (next, request)) :
    issue state = some (next, request) := by
  unfold issueReady at issued
  split at issued
  · exact issued
  · contradiction

end POO.Flow.SearchReadiness
