-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import LeanPoo.Prototype.C3GraphSemantics
import LeanPoo.C4.OrderRelation

namespace POO.Flow.Composition

/-- Role inheritance and C4 precedence remain separate algorithm inputs. -/
structure Orders (roles : LeanPoo.Prototype.C3.Graph) (roots : List String)
    (graph : LeanPoo.C4.Graph) (root : String) where
  c3 : LeanPoo.Prototype.C3.GraphCertificate roles roots
  c4 : LeanPoo.C4.VerifiedOrder graph root

theorem roles_match_source {roles : LeanPoo.Prototype.C3.Graph} {roots : List String}
    {graph : LeanPoo.C4.Graph} {root : String} (orders : Orders roles roots graph root) :
    LeanPoo.Prototype.C3.linearizeMany roles roots =
      LeanPoo.Prototype.C3.linearizeUncachedMany roles roots := orders.c3.agrees

theorem roles_have_source_derivations {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root : String}
    (orders : Orders roles roots graph root) :
    LeanPoo.Prototype.C3.ParentDerivations roles roots orders.c3.orders :=
  orders.c3.derivations

theorem role_order_count {roles : LeanPoo.Prototype.C3.Graph} {roots : List String}
    {graph : LeanPoo.C4.Graph} {root : String} (orders : Orders roles roots graph root) :
    orders.c3.orders.length = roots.length := orders.c3.order_count

theorem precedence_has_no_duplicates {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root : String}
    (orders : Orders roles roots graph root) : orders.c4.output.Nodup := orders.c4.nodup

theorem precedence_covers_ancestry {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root name : String}
    (orders : Orders roles roots graph root) :
    name ∈ orders.c4.output ↔ LeanPoo.C4.Ancestor graph name root := orders.c4.covers

theorem precedence_length_bound {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root : String}
    (orders : Orders roles roots graph root) :
    orders.c4.output.length ≤ graph.nodes.length := orders.c4.length_bound

theorem precedence_retains_ancestor_constraints {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root name : String}
    {node : LeanPoo.C4.Node} {constraint : List String}
    (orders : Orders roles roots graph root) (reachable : LeanPoo.C4.Ancestor graph name root)
    (found : graph.findNode? name = some node) (declared : constraint ∈ node.parentOrders) :
    constraint.Sublist orders.c4.output := orders.c4.ancestor_local_order reachable found declared

theorem precedence_monotone_in_descendants {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root ancestor left right : String}
    (orders : Orders roles roots graph root) (ancestorOrder : LeanPoo.C4.VerifiedOrder graph ancestor)
    (reachable : LeanPoo.C4.Ancestor graph ancestor root)
    (before : ancestorOrder.precedes left right = true) :
    orders.c4.precedes left right = true :=
  orders.c4.monotone_precedes ancestorOrder reachable before

theorem mapped_identities_have_no_duplicates {Element : Type}
    {roles : LeanPoo.Prototype.C3.Graph} {roots : List String}
    {graph : LeanPoo.C4.Graph} {root : String} (orders : Orders roles roots graph root)
    (identify : String → Element) (injective : Function.Injective identify) :
    (orders.c4.output.map identify).Nodup := by
  exact orders.c4.nodup.map identify (by
    intro left right different equal
    exact different (injective equal))

theorem mapped_precedence {Element : Type} {roles : LeanPoo.Prototype.C3.Graph}
    {roots : List String} {graph : LeanPoo.C4.Graph} {root : String}
    (orders : Orders roles roots graph root) (identify : String → Element)
    (left right : String) (accepted : orders.c4.precedes left right = true) :
    [identify left, identify right].Sublist (orders.c4.output.map identify) :=
  (orders.c4.precedes_iff.mp accepted).map identify

/-- Typed arrows admit sequential and fan-out/fan-in composition explicitly. -/
structure Stage (Input Output : Type) where
  run : Input → Output

def thenStage {A B C : Type} (left : Stage A B) (right : Stage B C) : Stage A C :=
  ⟨fun input => right.run (left.run input)⟩

def parallel {A B C : Type} (left : Stage A B) (right : Stage A C) : Stage A (B × C) :=
  ⟨fun input => (left.run input, right.run input)⟩

theorem sequential_assoc {A B C D : Type} (a : Stage A B) (b : Stage B C)
    (c : Stage C D) : (thenStage (thenStage a b) c).run =
      (thenStage a (thenStage b c)).run := rfl

end POO.Flow.Composition
