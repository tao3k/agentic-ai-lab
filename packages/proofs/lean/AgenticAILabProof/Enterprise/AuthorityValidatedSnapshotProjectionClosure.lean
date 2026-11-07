-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure

namespace AgenticAILabProof.Enterprise.AuthorityValidatedSnapshotProjectionClosure

open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure

structure SnapshotProjection (Snapshot Payload : Type) where
  snapshotIdentity : Snapshot
  payload : Payload

structure SnapshotProjectionAuthority (Snapshot Payload : Type) where
  validation : AcceptanceAuthority Snapshot (SnapshotProjection Snapshot Payload)
  validationBindsSnapshot :
    ∀ snapshot projection,
      validation.validate snapshot = some projection →
        projection.snapshotIdentity = snapshot

theorem authorityValidatedSnapshotProjectionIsAccepted
    {Snapshot Payload : Type}
    (authority : SnapshotProjectionAuthority Snapshot Payload)
    (node :
      AuthorityBoundNode
        Snapshot
        (SnapshotProjection Snapshot Payload)
        authority.validation) :
    authority.validation.accepted node.nodeBinding :=
  authorityValidatedNodeIsAccepted authority.validation node

theorem authorityValidatedProjectionBindsSnapshotKey
    {Snapshot Payload : Type}
    (authority : SnapshotProjectionAuthority Snapshot Payload)
    (node :
      AuthorityBoundNode
        Snapshot
        (SnapshotProjection Snapshot Payload)
        authority.validation) :
    node.nodeBinding.snapshotIdentity = node.artifact := by
  have validated :=
    authority.validationBindsSnapshot
      node.artifact node.validatedBinding node.validation
  calc
    node.nodeBinding.snapshotIdentity =
        node.validatedBinding.snapshotIdentity :=
      congrArg SnapshotProjection.snapshotIdentity node.exactBinding.symm
    _ = node.artifact := validated

theorem oneValidatedSnapshotSelectsOnePayload
    {Snapshot Payload : Type}
    (authority : SnapshotProjectionAuthority Snapshot Payload)
    (left right :
      AuthorityBoundNode
        Snapshot
        (SnapshotProjection Snapshot Payload)
        authority.validation)
    (sameSnapshot : left.artifact = right.artifact) :
    left.nodeBinding.payload = right.nodeBinding.payload := by
  have validatedBindingsEqual :
      left.validatedBinding = right.validatedBinding := by
    apply Option.some.inj
    calc
      some left.validatedBinding = authority.validation.validate left.artifact :=
        left.validation.symm
      _ = authority.validation.validate right.artifact :=
        congrArg authority.validation.validate sameSnapshot
      _ = some right.validatedBinding := right.validation
  calc
    left.nodeBinding.payload = left.validatedBinding.payload :=
      congrArg SnapshotProjection.payload left.exactBinding.symm
    _ = right.validatedBinding.payload :=
      congrArg SnapshotProjection.payload validatedBindingsEqual
    _ = right.nodeBinding.payload :=
      congrArg SnapshotProjection.payload right.exactBinding

end AgenticAILabProof.Enterprise.AuthorityValidatedSnapshotProjectionClosure
