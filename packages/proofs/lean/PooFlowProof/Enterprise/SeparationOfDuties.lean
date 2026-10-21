-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.Admission.Decision

namespace PooFlowProof.Enterprise.SeparationOfDuties

structure ApprovalDiscipline (Principal : Type) [DecidableEq Principal] where
  quorum : PooFlowCoreProof.Admission.Decision.QuorumEvidence Principal
  quorumAdmitted : PooFlowCoreProof.Admission.Decision.quorumSatisfied quorum
  separation :
    PooFlowCoreProof.Admission.Decision.SeparationOfDuties Principal

theorem quorumThresholdIsSatisfied
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.quorum.threshold ≤ discipline.quorum.approvingPrincipals.eraseDups.length :=
  discipline.quorumAdmitted

theorem proposerCannotApprove
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.proposer ≠ discipline.separation.approver :=
  PooFlowCoreProof.Admission.Decision.proposerAndApproverAreSeparated
    discipline.separation

theorem approverCannotExecute
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.approver ≠ discipline.separation.executor :=
  PooFlowCoreProof.Admission.Decision.approverAndExecutorAreSeparated
    discipline.separation

end PooFlowProof.Enterprise.SeparationOfDuties
