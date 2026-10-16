-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowProof.PooC4.CedarAdapterContract
import PooFlowProof.PooC4.CedarCapabilityRiskProjection
import PooFlowCoreProof.PooC4.GerbilPooPhysicalRefinement

namespace PooFlowProof.PooC4.CedarPooAdapterRefinement

/-!
Physical `gerbil-poo` refinement of the single POO Flow Cedar adapter owner.

The adapter has exactly three physical POO object slots: the definitional
engine, the production engine, and the arbitration policy.  Request, entity,
policy-set, ProfileBundle, capability, outcome, and receipt values are
invocation data or derived observations, never adapter object slots.
-/

structure PhysicalCedarEngine
    (EngineIdentity SemanticVersion EngineHandle : Type) where
  identity : EngineIdentity
  semanticVersion : SemanticVersion
  handle : EngineHandle

structure PhysicalCedarAdapter
    (EngineObject PolicyObject : Type) where
  definitionalEngine : EngineObject
  productionEngine : EngineObject
  arbitrationPolicy : PolicyObject

structure CedarAdapterProjectionOps
    (EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type) where
  engineIdentity : EngineObject → EngineIdentity
  engineSemanticVersion : EngineObject → SemanticVersion
  policyIdentity : PolicyObject → PolicyIdentity
  digestAdapter :
    EngineIdentity →
      EngineIdentity →
      SemanticVersion →
      PolicyIdentity →
      AdapterIdentity

def adapterSemanticVersion
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    SemanticVersion :=
  ops.engineSemanticVersion adapter.definitionalEngine

def adapterIdentity
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    AdapterIdentity :=
  ops.digestAdapter
    (ops.engineIdentity adapter.definitionalEngine)
    (ops.engineIdentity adapter.productionEngine)
    (adapterSemanticVersion ops adapter)
    (ops.policyIdentity adapter.arbitrationPolicy)

structure CedarAdapterAdmission
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) : Prop where
  semanticVersionAgreement :
    ops.engineSemanticVersion adapter.definitionalEngine =
      ops.engineSemanticVersion adapter.productionEngine
  independentEngineIdentities :
    ops.engineIdentity adapter.definitionalEngine ≠
      ops.engineIdentity adapter.productionEngine

structure CedarAdapterObservation
    (EngineIdentity SemanticVersion PolicyIdentity AdapterIdentity : Type) where
  definitionalEngineIdentity : EngineIdentity
  productionEngineIdentity : EngineIdentity
  semanticVersion : SemanticVersion
  arbitrationPolicyIdentity : PolicyIdentity
  adapterIdentity : AdapterIdentity

def observeCedarAdapter
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    CedarAdapterObservation
      EngineIdentity SemanticVersion PolicyIdentity AdapterIdentity :=
  { definitionalEngineIdentity :=
      ops.engineIdentity adapter.definitionalEngine
    productionEngineIdentity :=
      ops.engineIdentity adapter.productionEngine
    semanticVersion := adapterSemanticVersion ops adapter
    arbitrationPolicyIdentity :=
      ops.policyIdentity adapter.arbitrationPolicy
    adapterIdentity := adapterIdentity ops adapter }

def RefinesPhysicalCedarAdapter
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (abstract :
      CedarAdapterObservation
        EngineIdentity SemanticVersion PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    Prop :=
  observeCedarAdapter ops adapter = abstract

theorem adapter_retains_definitional_engine
    {EngineObject PolicyObject : Type}
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    adapter.definitionalEngine = adapter.definitionalEngine := by
  rfl

theorem adapter_retains_production_engine
    {EngineObject PolicyObject : Type}
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    adapter.productionEngine = adapter.productionEngine := by
  rfl

theorem adapter_retains_arbitration_policy
    {EngineObject PolicyObject : Type}
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    adapter.arbitrationPolicy = adapter.arbitrationPolicy := by
  rfl

theorem adapter_identity_is_derived
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    adapterIdentity ops adapter =
      ops.digestAdapter
        (ops.engineIdentity adapter.definitionalEngine)
        (ops.engineIdentity adapter.productionEngine)
        (ops.engineSemanticVersion adapter.definitionalEngine)
        (ops.policyIdentity adapter.arbitrationPolicy) := by
  rfl

theorem admitted_version_is_shared
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    {ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity}
    {adapter : PhysicalCedarAdapter EngineObject PolicyObject}
    (admission : CedarAdapterAdmission ops adapter) :
    adapterSemanticVersion ops adapter =
      ops.engineSemanticVersion adapter.productionEngine :=
  admission.semanticVersionAgreement

theorem same_engine_identity_blocks_admission
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject)
    (same :
      ops.engineIdentity adapter.definitionalEngine =
        ops.engineIdentity adapter.productionEngine) :
    ¬CedarAdapterAdmission ops adapter := by
  intro admission
  exact admission.independentEngineIdentities same

theorem version_disagreement_blocks_admission
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject)
    (different :
      ops.engineSemanticVersion adapter.definitionalEngine ≠
        ops.engineSemanticVersion adapter.productionEngine) :
    ¬CedarAdapterAdmission ops adapter := by
  intro admission
  exact different admission.semanticVersionAgreement

theorem three_physical_fields_determine_adapter
    {EngineObject PolicyObject : Type}
    (left right : PhysicalCedarAdapter EngineObject PolicyObject)
    (sameDefinitional :
      left.definitionalEngine = right.definitionalEngine)
    (sameProduction :
      left.productionEngine = right.productionEngine)
    (samePolicy :
      left.arbitrationPolicy = right.arbitrationPolicy) :
    left = right := by
  cases left
  cases right
  simp_all

theorem equal_adapters_have_equal_observations
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    {left right : PhysicalCedarAdapter EngineObject PolicyObject}
    (equalAdapters : left = right) :
    observeCedarAdapter ops left = observeCedarAdapter ops right := by
  exact congrArg (observeCedarAdapter ops) equalAdapters

theorem physical_refinement_is_exact_observation
    {EngineObject PolicyObject EngineIdentity SemanticVersion
      PolicyIdentity AdapterIdentity : Type}
    (ops :
      CedarAdapterProjectionOps
        EngineObject PolicyObject EngineIdentity SemanticVersion
        PolicyIdentity AdapterIdentity)
    (adapter : PhysicalCedarAdapter EngineObject PolicyObject) :
    RefinesPhysicalCedarAdapter
      ops (observeCedarAdapter ops adapter) adapter := by
  rfl

end PooFlowProof.PooC4.CedarPooAdapterRefinement
