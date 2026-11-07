-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.Semantics

namespace AgenticAILabProof.PooC4

def natScopeOrder : ScopeOrder Nat :=
  { le := Nat.le
    refl := Nat.le_refl
    trans := by
      intro _ _ _ left right
      exact Nat.le_trans left right
    antisymm := by
      intro _ _ left right
      exact Nat.le_antisymm left right }

end AgenticAILabProof.PooC4
