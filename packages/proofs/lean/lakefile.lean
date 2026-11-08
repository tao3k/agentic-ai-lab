-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Lake
open System Lake DSL

package «agentic-ai-lab-proof» where
  version := v!"0.1.0"

-- Published consumers must not depend on an uninitialized sibling submodule.
-- This revision is identical to the root repository's Core gitlink.
require YuanxuProof from git
  "https://github.com/tao3k/gebril-yuanxu.git"
  @ "272c46bebb73fff524b62e8eee77fc61befea2af"
  / "dev/proofs/lean"

require Cedar from git
  "https://github.com/cedar-policy/cedar-spec.git"
  @ "acb0db7daa838249d894d2af64c850e1c9bf0d7d"
  / "cedar-lean"

lean_lib AgenticAILabProof where
  roots := #[`AgenticAILabProof]

/-!
Runtime module libraries mirror proof-bearing owners under `modules`.
Lake derives each complete import closure from these roots; no external scanner
or changed-file projection owns the proof graph. `AgenticAILabProof` above remains
the explicit repository-wide integration aggregate.
-/
lean_lib AgenticAILabModuleGovernanceProof where
  roots := #[
    `AgenticAILabProof.PooC4.GovernanceCore,
    `AgenticAILabProof.Enterprise.GovernanceThreatAssuranceClosure
  ]

lean_lib AgenticAILabModuleTemporalCausalityProof where
  roots := #[
    `AgenticAILabProof.PooC4.TemporalCausality,
    `AgenticAILabProof.PooC4.TemporalBoundedTime,
    `AgenticAILabProof.PooC4.TemporalEvidenceRevision
  ]

/-! Scenario refinements compose module libraries without becoming a second
module graph.  This target owns the exact Healthcare Case declarations. -/
lean_lib AgenticAILabScenarioHealthcareProof where
  roots := #[
    `AgenticAILabProof.Vertical.Healthcare.PrescriptionCausalityRefinement,
    `AgenticAILabProof.Vertical.Healthcare.StandardMigrationRefinement
  ]

lean_lib AgenticAILabModuleAuthorizationProof where
  roots := #[
    `AgenticAILabProof.PooC4.CedarPooAdapterRefinement,
    `AgenticAILabProof.Enterprise.CedarDualEngineAuthorization
  ]

lean_lib AgenticAILabModuleLoopEngineProof where
  roots := #[
    `AgenticAILabProof.PooC4.LoopEngineGraph
  ]

lean_lib AgenticAILabModuleSessionProof where
  roots := #[
    `AgenticAILabProof.PooC4.SessionControlLink,
    `AgenticAILabProof.PooC4.AgentLifecycleTopology
  ]

lean_lib AgenticAILabModuleSandboxCoreProof where
  roots := #[
    `AgenticAILabProof.PooC4.Sandbox,
    `AgenticAILabProof.PooC4.CapabilityRoleIsolation
  ]

lean_lib AgenticAILabModuleFunflowProof where
  roots := #[`AgenticAILabProof.PooC4.FunctionalFlow]

lean_lib AgenticAILabModuleWorkflowProof where
  roots := #[
    `AgenticAILabProof.PooC4.PolicyTrace,
    `AgenticAILabProof.PooC4.EffectDagAtomicity
  ]

lean_lib AgenticAILabModuleMemoryCoreProof where
  roots := #[
    `AgenticAILabProof.PooC4.RecoveryPolicyAuthorization
  ]

target proof_runtime.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "runtime" / "agentic_ai_lab_proof_ffi.c"
  let obj := pkg.buildDir / "runtime" / "agentic_ai_lab_proof_ffi.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-fPIC"]

extern_lib proof_runtime (pkg : NPackage __name__) := do
  let name := nameToStaticLib "proof_runtime"
  let obj ← fetch <| pkg.target ``proof_runtime.o
  buildStaticLib (pkg.buildDir / "lib" / name) #[obj]

lean_exe ffiSmoke where
  root := `AgenticAILabProof.FFISmoke

lean_exe agenticAiLabDeclarationClosure where
  root := `AgenticAILabProof.Export.DeclarationClosure

target cedar_runtime_probe.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "runtime" / "cedar_runtime_probe.c"
  let obj := pkg.buildDir / "runtime" / "cedar_runtime_probe.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-O2", "-Wall", "-Wextra", "-Werror", "-pthread"]

-- A C-owned main calls Lean's exported function on a dedicated runtime thread.
-- Lake owns the transitive object graph, just as for the diagnostic executable.
lean_exe cedarRuntimeProbe where
  root := `AgenticAILabProof.Runtime.CedarRuntime
  moreLinkObjs := #[cedar_runtime_probe.o]
  moreLinkArgs := #["-pthread"]

target cedar_runtime_host.o (pkg : NPackage __name__) : FilePath := do
  let src := pkg.dir / "runtime" / "cedar_runtime_host.c"
  let obj := pkg.buildDir / "runtime" / "cedar_runtime_host.o"
  buildFileAfterDep obj (← inputFile src true) fun srcFile => do
    let leanDir := (← getLeanIncludeDir).toString
    compileO obj srcFile #["-I", leanDir, "-O2", "-Wall", "-Wextra", "-Werror", "-pthread"]

target cedar_runtime_core.a (_pkg : NPackage __name__) : FilePath := do
  let some archive ← IO.getEnv "AGENTIC_AI_LAB_CEDAR_RUNTIME_CORE_ARCHIVE"
    | error "AGENTIC_AI_LAB_CEDAR_RUNTIME_CORE_ARCHIVE must name the Rust static archive"
  inputFile archive false

-- The outer build supplies the Cargo archive as an explicit input. The final
-- executable contains both Cedar engines and the Runtime Host; it discovers
-- no Lake cache or repository path at runtime.
lean_exe cedarRuntimeHost where
  root := `AgenticAILabProof.Runtime.CedarRuntimeHost
  moreLinkObjs := #[cedar_runtime_host.o, cedar_runtime_core.a]
  moreLinkArgs := #["-pthread"]

lean_lib AgenticAILabModuleEvidenceAssessmentProof where
  roots := #[`AgenticAILabProof.EvidenceAssessment.ClueSubmission, `AgenticAILabProof.EvidenceAssessment.AnchoredEvidenceSlice, `AgenticAILabProof.EvidenceAssessment.DomainEvidence, `AgenticAILabProof.EvidenceAssessment.EvidenceCheckpoint, `AgenticAILabProof.EvidenceAssessment.EvidenceInteraction, `AgenticAILabProof.EvidenceAssessment.Trajectory, `AgenticAILabProof.EvidenceAssessment.AccountingAbstraction]
