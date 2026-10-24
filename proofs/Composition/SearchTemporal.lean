-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import LeanPoo.Proof.Invalidation
namespace POO.Flow.SearchTemporal

/-- Structural dependency projection only: source authentication remains external.
The caller must establish that graph edges represent the actual stage dependencies. -/
abbrev ImpactCertificate := LeanPoo.Proof.CertifiedInvalidation

def certifyImpact (graph : LeanPoo.C4.Graph) (changed : List String) :=
  LeanPoo.Proof.certifyInvalidation graph changed

theorem affected_exact {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : ImpactCertificate graph changed) (stage : String) :
    stage ∈ certificate.names ↔
    ∃ origin ∈ changed, ∃ steps, LeanPoo.Proof.Descendant graph origin steps stage :=
  certificate.characterizes stage

theorem unaffected_not_invalidated {graph : LeanPoo.C4.Graph} {changed : List String}
    (certificate : ImpactCertificate graph changed) (stage : String)
    (unaffected : ¬ ∃ origin ∈ changed, ∃ steps,
      LeanPoo.Proof.Descendant graph origin steps stage) :
    stage ∉ certificate.names :=
  fun member => unaffected ((certificate.characterizes stage).mp member)

end POO.Flow.SearchTemporal
