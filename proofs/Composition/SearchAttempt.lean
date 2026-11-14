-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
namespace POO.Flow.SearchAttempt
def quintSourceDigest : String := "sha256:6925f9de5a50181e73b0a5e6dda4da2487807e82128576606a38d3ab538e24ce"
def quintInvariantNames : List String := ["CurrentRevision", "ExactAttempt", "NoRetiredAdmission", "OncePerAttempt", "NoStaleCancellation"]
structure Scope where
  stage : Nat
  generation : Nat
  configuration : Nat
  sourceCut : Nat
  revision : Nat
  deriving DecidableEq
structure Request where
  scope : Scope
  attempt : Nat
  deriving DecidableEq
structure State where
  scope : Scope
  nextAttempt : Nat
  active : Option Request
  retired : Bool

abbrev Admits (state : State) (request : Request) : Prop :=
  state.retired = false ∧ state.active = some request ∧ request.scope = state.scope

def issue (state : State) : Option (State × Request) :=
  if state.retired = false ∧ state.active = none then
    let request := Request.mk state.scope state.nextAttempt
    some ({state with active := some request, nextAttempt := state.nextAttempt + 1}, request)
  else none

def settle (state : State) (request : Request) : Option State :=
  if Admits state request then some {state with active := none} else none

def revise (state : State) (sourceCut : Nat) : Option State :=
  if state.retired = false then
    let scope := {state.scope with sourceCut := sourceCut, revision := state.scope.revision + 1}
    some {state with scope := scope, active := none}
  else none

def retire (state : State) : State := {state with retired := true}

theorem settlement_exact {state next : State} {request : Request}
    (accepted : settle state request = some next) : Admits state request := by
  unfold settle at accepted
  split at accepted
  · assumption
  · contradiction

theorem settled_once {state next : State} {request : Request}
    (accepted : settle state request = some next) :
    settle next request = none := by
  unfold settle at accepted
  split at accepted
  · cases accepted
    simp [settle, Admits]
  · contradiction

theorem different_scope_rejects (state : State) (request : Request)
    (different : request.scope ≠ state.scope) : settle state request = none := by
  simp [settle, Admits, different]

theorem retired_rejects (state : State) (request : Request) :
    settle (retire state) request = none := by
  simp [settle, Admits, retire]

theorem retired_cannot_issue (state : State) : issue (retire state) = none := by
  simp [issue, retire]

theorem retired_cannot_revise (state : State) (cut : Nat) :
    revise (retire state) cut = none := by
  simp [revise, retire]

theorem revision_fences_old_attempt {state next : State} {request : Request} {cut : Nat}
    (changed : revise state cut = some next) :
    settle next request = none := by
  unfold revise at changed
  split at changed
  · cases changed
    simp [settle, Admits]
  · contradiction

def cancel (state : State) (request : Request) : Option State :=
  if Admits state request then revise state state.scope.sourceCut else some state

theorem stale_cancel_noop (state : State) (request : Request)
    (stale : ¬ Admits state request) : cancel state request = some state := by
  simp [cancel, stale]

theorem cancelled_attempt_cannot_settle
    {state next : State} {request : Request}
    (current : Admits state request) (cancelled : cancel state request = some next) :
    settle next request = none := by
  have revised : revise state state.scope.sourceCut = some next := by
    unfold cancel at cancelled
    split at cancelled
    · exact cancelled
    · contradiction
  exact revision_fences_old_attempt revised

theorem issued_identity {state next : State} {request : Request}
    (issued : issue state = some (next, request)) :
    request.scope = state.scope ∧ request.attempt = state.nextAttempt ∧
    next.nextAttempt = state.nextAttempt + 1 := by
  unfold issue at issued
  split at issued
  · cases issued
    simp
  · contradiction
end POO.Flow.SearchAttempt
