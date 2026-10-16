-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.PooC4.GovernanceDecisionAuthority

namespace PooFlowProof.Enterprise.SeparationOfDuties

open PooFlowProof.PooC4

structure ApprovalDiscipline (Principal : Type) where
  quorum : GovernanceDecisionAuthority.QuorumEvidence Principal
  separation :
    GovernanceDecisionAuthority.SeparationOfDuties Principal

theorem approvingPrincipalsAreDistinct
    {Principal : Type}
    (discipline : ApprovalDiscipline Principal) :
    discipline.quorum.approvingPrincipals.Nodup :=
  GovernanceDecisionAuthority.quorumCarriesDistinctPrincipals
    discipline.quorum

theorem quorumThresholdIsSatisfied
    {Principal : Type}
    (discipline : ApprovalDiscipline Principal) :
    discipline.quorum.thresholdSatisfied :=
  GovernanceDecisionAuthority.quorumCarriesThresholdEvidence
    discipline.quorum

theorem proposerCannotApprove
    {Principal : Type}
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.proposer ≠ discipline.separation.approver :=
  GovernanceDecisionAuthority.proposerAndApproverAreSeparated
    discipline.separation

theorem approverCannotExecute
    {Principal : Type}
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.approver ≠ discipline.separation.executor :=
  GovernanceDecisionAuthority.approverAndExecutorAreSeparated
    discipline.separation

end PooFlowProof.Enterprise.SeparationOfDuties
