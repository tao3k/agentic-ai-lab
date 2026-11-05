-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Runtime.CedarRuntime

/-! Root identity for the AOT Runtime Host link graph. Runtime behavior lives
in the Rust staticlib and the exported CedarRuntime function. -/

namespace AgenticAILabProof.Runtime.CedarRuntimeHost

def linked : Bool := true

end AgenticAILabProof.Runtime.CedarRuntimeHost
