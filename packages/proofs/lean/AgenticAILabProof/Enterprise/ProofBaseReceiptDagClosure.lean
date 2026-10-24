-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.ProofBaseReceiptDagClosure

structure ReceiptDag (Node Interface : Type) where
  dependsOn : Node → Node → Prop
  accepted : Node → Prop
  providedInterface : Node → Interface
  assumedInterface : Node → Node → Interface
  exactInterfaceEdges :
    ∀ supplier consumer,
      dependsOn supplier consumer →
        providedInterface supplier = assumedInterface consumer supplier
  acceptanceStep :
    ∀ consumer,
      (∀ supplier, dependsOn supplier consumer → accepted supplier) →
        accepted consumer
  wellFounded : WellFounded dependsOn

theorem receiptDagClosesEveryNode
    {Node Interface : Type}
    (dag : ReceiptDag Node Interface) :
    ∀ node, dag.accepted node :=
  fun node =>
    dag.wellFounded.induction node fun consumer supplierAccepted =>
      dag.acceptanceStep consumer fun supplier dependency =>
        supplierAccepted supplier dependency

theorem receiptDagClosesTerminalComposition
    {Node Interface : Type}
    (dag : ReceiptDag Node Interface)
    (terminal : Node) :
    dag.accepted terminal ∧
      ∀ supplier,
        dag.dependsOn supplier terminal →
          dag.providedInterface supplier =
            dag.assumedInterface terminal supplier := by
  constructor
  · exact receiptDagClosesEveryNode dag terminal
  · intro supplier dependency
    exact dag.exactInterfaceEdges supplier terminal dependency

inductive CycleNode
  | left
  | right

def cycleDependsOn : CycleNode → CycleNode → Prop
  | .left, .right => True
  | .right, .left => True
  | _, _ => False

def neverAccepted (_ : CycleNode) : Prop :=
  False

theorem cyclicLocalStepsDoNotClose :
    (∀ consumer,
        (∀ supplier,
          cycleDependsOn supplier consumer →
            neverAccepted supplier) →
          neverAccepted consumer) ∧
      ¬ ∀ node, neverAccepted node := by
  constructor
  · intro consumer supplierAccepted
    cases consumer with
    | left =>
        exact supplierAccepted .right trivial
    | right =>
        exact supplierAccepted .left trivial
  · intro allAccepted
    exact allAccepted .left

end AgenticAILabProof.Enterprise.ProofBaseReceiptDagClosure
