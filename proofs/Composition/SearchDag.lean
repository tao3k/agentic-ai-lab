-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchReadiness
import SearchTemporal
namespace POO.Flow.SearchDag
open POO.Flow.SearchAttempt
def quintSourceDigest : String := "sha256:66156e809a815ceb9b409006e95d03a1231bc5019e853db279caa3e893133de3"
def quintInvariantNames : List String := ["DependencyOrder", "FreshResults", "BranchRetention"]

def ParentReady (state : State) (request completed : Option Request) : Prop :=
  match request with
  | none => False
  | some expected => completed = some expected ∧
      expected.scope.generation = state.scope.generation ∧
      expected.scope.configuration = state.scope.configuration
instance (state : State) (request completed : Option Request) :
    Decidable (ParentReady state request completed) := by
  cases request <;> simp only [ParentReady] <;> infer_instance

def Ready (node : LeanPoo.C4.Node) (state : State)
    (current completed : String → Option Request) : Prop :=
  state.retired = false ∧ state.active = none ∧ completed node.name = none ∧
    ∀ parent ∈ node.parentOrders.flatten, ParentReady state (current parent) (completed parent)
instance (node : LeanPoo.C4.Node) (state : State)
    (current completed : String → Option Request) :
    Decidable (Ready node state current completed) :=
  inferInstanceAs (Decidable (state.retired = false ∧ state.active = none ∧
    completed node.name = none ∧ ∀ parent ∈ node.parentOrders.flatten,
      ParentReady state (current parent) (completed parent)))

def frontier (graph : LeanPoo.C4.Graph) (states : String → State)
    (current completed : String → Option Request) : List String :=
  (graph.nodes.filter (fun node => decide (Ready node (states node.name) current completed))).map (·.name)

theorem frontier_exact (graph : LeanPoo.C4.Graph) (states : String → State)
    (current completed : String → Option Request) (name : String) :
    name ∈ frontier graph states current completed ↔
      ∃ node ∈ graph.nodes, node.name = name ∧ Ready node (states node.name) current completed := by
  simp only [frontier, List.mem_map, List.mem_filter, decide_eq_true_eq]
  constructor
  · rintro ⟨node, ⟨member, ready⟩, named⟩
    exact ⟨node, member, named, ready⟩
  · rintro ⟨node, member, named, ready⟩
    exact ⟨node, ⟨member, ready⟩, named⟩

def resetState (state : State) (cut : Nat) : State :=
  let scope := {state.scope with sourceCut := cut, revision := state.scope.revision + 1}
  {state with scope := scope, active := none}

def invalidateStates {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (states : String → State) (cut : Nat) (name : String) : State :=
  if name ∈ certificate.names then resetState (states name) cut else states name

def invalidateRequests {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (requests : String → Option Request) (name : String) : Option Request :=
  if name ∈ certificate.names then none else requests name

theorem unaffected_state_retained {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (states : String → State) (cut : Nat) (name : String)
    (safe : name ∉ certificate.names) :
    invalidateStates certificate states cut name = states name := by
  simp [invalidateStates, safe]

theorem unaffected_request_retained {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (requests : String → Option Request) (name : String)
    (safe : name ∉ certificate.names) :
    invalidateRequests certificate requests name = requests name := by
  simp [invalidateRequests, safe]

theorem affected_revision_and_active {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (states : String → State) (cut : Nat) (name : String)
    (affected : name ∈ certificate.names) :
    (invalidateStates certificate states cut name).scope.revision = (states name).scope.revision + 1 ∧
    (invalidateStates certificate states cut name).active = none ∧
    (invalidateStates certificate states cut name).nextAttempt = (states name).nextAttempt := by
  simp [invalidateStates, affected, resetState]

theorem descendant_receipt_cleared {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (completed : String → Option Request) (name origin : String) (steps : Nat)
    (changedOrigin : origin ∈ changed)
    (path : LeanPoo.Proof.Descendant graph origin steps name) :
    invalidateRequests certificate completed name = none := by
  have affected : name ∈ certificate.names :=
    (certificate.characterizes name).mpr ⟨origin, changedOrigin, steps, path⟩
  simp [invalidateRequests, affected]

theorem missing_current_parent_blocks (node : LeanPoo.C4.Node) (state : State)
    (current completed : String → Option Request) (parent : String)
    (edge : parent ∈ node.parentOrders.flatten) (missing : current parent = none) :
    ¬ Ready node state current completed := by
  intro ready
  have parentReady := ready.2.2.2 parent edge
  simp [ParentReady, missing] at parentReady

theorem affected_settlement_rejected {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (states : String → State) (cut : Nat) (name : String) (request : Request)
    (affected : name ∈ certificate.names) :
    settle (invalidateStates certificate states cut name) request = none := by
  simp [invalidateStates, affected, resetState, settle, Admits]

theorem descendant_settlement_rejected {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : POO.Flow.SearchTemporal.ImpactCertificate graph changed)
    (states : String → State) (cut : Nat) (name origin : String) (steps : Nat)
    (request : Request) (changedOrigin : origin ∈ changed)
    (path : LeanPoo.Proof.Descendant graph origin steps name) :
    settle (invalidateStates certificate states cut name) request = none := by
  exact affected_settlement_rejected certificate states cut name request
    ((certificate.characterizes name).mpr ⟨origin, changedOrigin, steps, path⟩)

end POO.Flow.SearchDag
