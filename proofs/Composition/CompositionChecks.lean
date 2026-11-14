-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabComposition

open POO.Flow.Composition

def main : IO Unit := do
  let roles : LeanPoo.Prototype.C3.Graph :=
    [("stage", ["acquisition", "audit"]), ("acquisition", []), ("audit", [])]
  let .ok c3 := LeanPoo.Prototype.C3.certifyGraph roles ["stage"]
    | throw (IO.userError "C3 source/cached admission failed")
  if c3.orders != [["stage", "acquisition", "audit"]] then
    throw (IO.userError "C3 role precedence mismatch")
  let inherited : LeanPoo.Prototype.C3.Graph :=
    [("stage", ["acquisition", "audit"]), ("acquisition", ["base"]),
      ("audit", ["base"]), ("base", [])]
  let .ok inheritedC3 := LeanPoo.Prototype.C3.certifyGraph inherited ["stage"]
    | throw (IO.userError "C3 shared-base source derivation failed")
  if inheritedC3.orders != [["stage", "acquisition", "audit", "base"]] then
    throw (IO.userError "C3 inherited role precedence mismatch")
  let graph : LeanPoo.C4.Graph := {nodes := [
    {name := "search", parentOrders := [["source", "merge", "publish"]]},
    {name := "source"}, {name := "merge"}, {name := "publish", suffix := true}]}
  let .ok c4 := LeanPoo.C4.linearizeVerified graph "search"
    | throw (IO.userError "C4 checked admission failed")
  if c4.output != ["search", "source", "merge", "publish"] then
    throw (IO.userError "C4 order mismatch")
  let orders : Orders roles ["stage"] graph "search" := ⟨c3, c4⟩
  if !(orders.c4.precedes "source" "publish") then
    throw (IO.userError "C4 source/publication precedence mismatch")
  let indexed := orders.c4.indexAncestors
  if !(indexed.isAncestor "publish") || indexed.isAncestor "foreign" then
    throw (IO.userError "C4 retained ancestry query mismatch")
  let invalid : LeanPoo.C4.Graph := {nodes := [
    {name := "root", parentOrders := [["a", "b"], ["b", "a"]]},
    {name := "a"}, {name := "b"}]}
  match LeanPoo.C4.linearizeVerified invalid "root" with
  | .ok _ => throw (IO.userError "contradictory precedence admitted")
  | .error _ => pure ()
  let acquire : Stage Nat (List Nat) := ⟨fun input => [input, input + 1]⟩
  let project : Stage (List Nat) Nat := ⟨List.length⟩
  if (thenStage acquire project).run 10 != 2 then
    throw (IO.userError "typed sequential composition mismatch")
  if (parallel acquire acquire).run 10 != ([10, 11], [10, 11]) then
    throw (IO.userError "typed parallel composition mismatch")
  IO.println "POO-COMPOSITION-OK: actual C3/C4 certificates and typed composition controls"

#print axioms roles_match_source
#print axioms roles_have_source_derivations
#print axioms role_order_count
#print axioms precedence_has_no_duplicates
#print axioms precedence_covers_ancestry
#print axioms precedence_length_bound
#print axioms precedence_retains_ancestor_constraints
#print axioms precedence_monotone_in_descendants
#print axioms mapped_identities_have_no_duplicates
#print axioms mapped_precedence
#print axioms sequential_assoc
