-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Cedar.Spec
import CedarProto.AuthorizationRequest
import Lean.Data.Json

/-!
One projection owner for native FFI and the diagnostic executable. The native
entry consumes an upstream protobuf ByteArray and returns an Except-owned
String; no expected decision, process launch, or alternate evaluator enters
this boundary. Initialization and Lean object lifetimes remain the host's duty.
-/

namespace AgenticAILabProof.Runtime.CedarNative

def authorizeProjection (bytes : ByteArray) : Except String Lean.Json := do
  let input ← (@Proto.Message.interpret? Cedar.Spec.AuthorizationRequest) bytes
  let response := Cedar.Spec.isAuthorized input.request input.entities input.policies
  return Lean.Json.mkObj [
    ("schema_id", Lean.toJson "agentic-ai-lab.cedar-engine-outcome.v1"),
    ("engine_id", Lean.toJson "cedar-lean"),
    ("semantic_revision", Lean.toJson "e9fa9c1e6b636f29b0897d8706bd7aa5eaf06f9a"),
    ("decision", Lean.toJson (match response.decision with
      | .allow => "allow"
      | .deny => "deny")),
    ("determining_policies", Lean.toJson response.determiningPolicies.toList),
    ("erroring_policies", Lean.toJson response.erroringPolicies.toList)]

/-- Lean C ABI: consumes its ByteArray and transfers ownership of Except String String. -/
@[export agentic_ai_lab_cedar_authorize_native]
def authorizeNative (bytes : ByteArray) : Except String String :=
  (authorizeProjection bytes).map Lean.Json.compress

end AgenticAILabProof.Runtime.CedarNative
