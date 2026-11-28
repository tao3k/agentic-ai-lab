-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.FFI

def main : IO Unit := do
  if (← AgenticAILabProof.cBridgeMatchesCanonical) then
    IO.println "agentic-ai-lab proof FFI smoke: ok"
  else
    throw <| IO.userError "agentic-ai-lab proof FFI smoke: proof ABI mismatch"
