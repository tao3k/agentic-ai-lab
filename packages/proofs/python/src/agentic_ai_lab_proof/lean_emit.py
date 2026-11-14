# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Emit Lean typed declarations from generator-side typed values."""

from __future__ import annotations

from .model import TypedManifest


def _lean_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def manifest_to_lean(manifest: TypedManifest, module_name: str) -> str:
    obligations = ",\n".join(
        "  { name := "
        + obligation.name
        + "\n    claim := "
        + obligation.claim
        + "\n    source := "
        + obligation.source
        + " }"
        for obligation in manifest.obligations
    )

    return f"""import AgenticAILabProof.Manifest

namespace {module_name}

open AgenticAILabProof

def generatedObligations : List Obligation :=
  [
{obligations}
  ]

def generatedManifest : ProofManifest :=
  {{ kind := ManifestKind.loopEngineProofManifest
    contract := ProofManifestContract.v1
    source := ManifestSource.userConfigLoopEngine
    proofOwner := ProofOwner.lean
    proofChecker := ProofChecker.axle
    runtimeOwner := RuntimeOwner.marlinAgentCore
    schemeProjection := SchemeProjection.loopEngineRuntimeCommandManifest
    proofScope :=
      [ ProofScope.userInterface
      , ProofScope.policy
      , ProofScope.strategy
      , ProofScope.workflow
      , ProofScope.runtimeHandoff
      ]
    requestId := {_lean_string(manifest.request_id)}
    artifactHandle := {_lean_string(manifest.artifact_handle)}
    runtimeCommandContract := RuntimeCommandContract.loopGovernorRuntimeCommandManifestV1
    objectFamilies := [ObjectFamily.agentProfile, ObjectFamily.runtimeSnapshot]
    receiptContracts := [ReceiptContract.lineageReceiptV1]
    runtimePacketContracts := [RuntimePacketContract.actionPacketV1]
    cAbi := {{
      version := 1
      requiredObligationMask := {manifest.required_obligation_mask}
      tagWidth := TagWidth.uint32
    }}
    obligations := generatedObligations
    leanArtifactKind := LeanArtifactKind.theoremStubs
    runtimeExecution := RuntimeExecution.inert }}

theorem generatedManifest_runtime_inert :
    generatedManifest.runtimeExecution = RuntimeExecution.inert :=
  ProofManifest.runtime_inert_by_type generatedManifest

theorem generatedManifest_has_required_obligations :
    generatedManifest.hasAllRequiredObligations = true := by
  native_decide

theorem generatedManifest_valid : generatedManifest.Valid where
  abiMatches := by native_decide
  hasRequiredObligations := generatedManifest_has_required_obligations

end {module_name}
"""
