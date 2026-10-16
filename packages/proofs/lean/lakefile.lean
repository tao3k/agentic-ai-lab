-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Lake
open System Lake DSL

package «poo-flow-proof» where
  version := v!"0.1.0"

require PooFlowCoreProof from "../../../core/proofs/lean"

require Cedar from git
  "https://github.com/cedar-policy/cedar-spec.git"
  @ "e9fa9c1e6b636f29b0897d8706bd7aa5eaf06f9a"
  / "cedar-lean"

lean_lib PooFlowProof where
  roots := #[`PooFlowProof]

/-!
Native module libraries mirror proof-bearing owners under `modules`.
Lake derives each complete import closure from these roots; no external scanner
or changed-file projection owns the proof graph. `PooFlowProof` above remains
the explicit repository-wide integration aggregate.
-/
lean_lib PooFlowModuleGovernanceProof where
  roots := #[
    `PooFlowProof.PooC4.GovernanceCore,
    `PooFlowProof.Enterprise.GovernanceThreatAssuranceClosure
  ]

lean_lib PooFlowModuleTemporalCausalityProof where
  roots := #[
    `PooFlowProof.PooC4.TemporalCausality,
    `PooFlowProof.PooC4.TemporalBoundedTime,
    `PooFlowProof.PooC4.TemporalEvidenceRevision
  ]

/-! Scenario refinements compose module libraries without becoming a second
module graph.  This target owns the exact Healthcare Case declarations. -/
lean_lib PooFlowScenarioHealthcareProof where
  roots := #[
    `PooFlowProof.Vertical.Healthcare.PrescriptionCausalityRefinement,
    `PooFlowProof.Vertical.Healthcare.StandardMigrationRefinement
  ]

lean_lib PooFlowModuleAuthorizationProof where
  roots := #[
    `PooFlowProof.PooC4.CedarPooAdapterRefinement,
    `PooFlowProof.Enterprise.CedarDualEngineAuthorization
  ]

lean_lib PooFlowModuleLoopEngineProof where
  roots := #[
    `PooFlowProof.PooC4.LoopEngineGraph
  ]

lean_lib PooFlowModuleSessionProof where
  roots := #[
    `PooFlowProof.PooC4.SessionControlLink,
    `PooFlowProof.PooC4.AgentLifecycleTopology
  ]

lean_lib PooFlowModuleSandboxCoreProof where
  roots := #[
    `PooFlowProof.PooC4.Sandbox,
    `PooFlowProof.PooC4.CapabilityRoleIsolation
  ]

lean_lib PooFlowModuleFunflowProof where
  roots := #[`PooFlowProof.PooC4.FunctionalFlow]

lean_lib PooFlowModuleWorkflowProof where
  roots := #[
    `PooFlowProof.PooC4.PolicyTrace,
    `PooFlowProof.PooC4.EffectDagAtomicity
  ]

lean_lib PooFlowModuleMemoryCoreProof where
  roots := #[
    `PooFlowProof.PooC4.RecoveryPolicyAuthorization
  ]

target proof_native.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "native" / "poo_flow_proof_ffi.c"
  let obj := pkg.buildDir / "native" / "poo_flow_proof_ffi.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-fPIC"]

extern_lib proof_native (pkg : NPackage __name__) := do
  let name := nameToStaticLib "proof_native"
  let obj ← fetch <| pkg.target ``proof_native.o
  buildStaticLib (pkg.buildDir / "lib" / name) #[obj]

lean_exe ffiSmoke where
  root := `PooFlowProof.FFISmoke

lean_exe pooFlowDeclarationClosure where
  root := `PooFlowProof.Export.DeclarationClosure

target cedar_native_probe.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "native" / "cedar_native_probe.c"
  let obj := pkg.buildDir / "native" / "cedar_native_probe.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-O2", "-Wall", "-Wextra", "-Werror", "-pthread"]

-- A C-owned main calls Lean's exported function on a dedicated native thread.
-- Lake owns the transitive object graph, just as for the diagnostic executable.
lean_exe cedarNativeProbe where
  root := `PooFlowProof.Runtime.CedarNative
  moreLinkObjs := #[cedar_native_probe.o]
  moreLinkArgs := #["-pthread"]

target cedar_runtime_host.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "native" / "cedar_runtime_host.c"
  let obj := pkg.buildDir / "native" / "cedar_runtime_host.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-O2", "-Wall", "-Wextra", "-Werror", "-pthread"]

target cedar_runtime_core.a (_pkg : NPackage __name__) : FilePath := do
  let some archive ← IO.getEnv "POO_FLOW_CEDAR_RUNTIME_CORE_ARCHIVE"
    | error "POO_FLOW_CEDAR_RUNTIME_CORE_ARCHIVE must name the Rust static archive"
  inputFile archive false

-- The outer build supplies the Cargo archive as an explicit input. The final
-- executable contains both Cedar engines and the Runtime Host; it discovers
-- no Lake cache or repository path at runtime.
lean_exe cedarRuntimeHost where
  root := `PooFlowProof.Runtime.CedarRuntimeHost
  moreLinkObjs := #[cedar_runtime_host.o, cedar_runtime_core.a]
  moreLinkArgs := #["-pthread"]
