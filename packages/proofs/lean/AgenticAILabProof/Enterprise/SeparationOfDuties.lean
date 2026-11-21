-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import YuanxuProof.Admission.Decision

namespace AgenticAILabProof.Enterprise.SeparationOfDuties

structure ApprovalDiscipline (Principal : Type) [DecidableEq Principal] where
  quorum : YuanxuProof.Admission.Decision.QuorumEvidence Principal
  quorumAdmitted : YuanxuProof.Admission.Decision.quorumSatisfied quorum
  separation :
    YuanxuProof.Admission.Decision.SeparationOfDuties Principal

theorem quorumThresholdIsSatisfied
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.quorum.threshold ≤ discipline.quorum.approvingPrincipals.eraseDups.length :=
  discipline.quorumAdmitted

theorem proposerCannotApprove
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.proposer ≠ discipline.separation.approver :=
  YuanxuProof.Admission.Decision.proposerAndApproverAreSeparated
    discipline.separation

theorem approverCannotExecute
    {Principal : Type} [DecidableEq Principal]
    (discipline : ApprovalDiscipline Principal) :
    discipline.separation.approver ≠ discipline.separation.executor :=
  YuanxuProof.Admission.Decision.approverAndExecutorAreSeparated
    discipline.separation

end AgenticAILabProof.Enterprise.SeparationOfDuties
