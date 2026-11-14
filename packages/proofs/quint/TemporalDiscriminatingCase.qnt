// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalDiscriminatingCase {
  import TemporalFamily(OBS = Set(("source-a","timeline",1,"ledger","observed"),("source-b","timeline",4,"ledger","observed"),("result","timeline",3,"ledger","observed")), LIMIT = 0, EXPECTED = Set("necessary"), CONSTRAINTS = Set(), BUG = false).* from "./TemporalFamily"
}
