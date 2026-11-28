-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.EvidenceFreshness

structure Checks where
  exactEvidenceCut : Prop
  validityIntervalHolds : Prop
  revocationObservationCurrent : Prop
  notRevoked : Prop
  policyRevisionCurrent : Prop
  sourceRevisionCurrent : Prop

def Hold (checks : Checks) : Prop :=
  checks.exactEvidenceCut ∧
    checks.validityIntervalHolds ∧
    checks.revocationObservationCurrent ∧
    checks.notRevoked ∧
    checks.policyRevisionCurrent ∧
    checks.sourceRevisionCurrent

theorem allChecksRequired
    (checks : Checks)
    (hold : Hold checks) :
    checks.exactEvidenceCut ∧
      checks.validityIntervalHolds ∧
      checks.revocationObservationCurrent ∧
      checks.notRevoked ∧
      checks.policyRevisionCurrent ∧
      checks.sourceRevisionCurrent :=
  hold

theorem stalePolicyBlocksFreshness
    (checks : Checks)
    (stale : ¬ checks.policyRevisionCurrent) :
    ¬ Hold checks := by
  intro hold
  exact stale hold.2.2.2.2.1

theorem staleSourceBlocksFreshness
    (checks : Checks)
    (stale : ¬ checks.sourceRevisionCurrent) :
    ¬ Hold checks := by
  intro hold
  exact stale hold.2.2.2.2.2

theorem revokedEvidenceBlocksFreshness
    (checks : Checks)
    (revoked : ¬ checks.notRevoked) :
    ¬ Hold checks := by
  intro hold
  exact revoked hold.2.2.2.1

end AgenticAILabProof.Enterprise.EvidenceFreshness
