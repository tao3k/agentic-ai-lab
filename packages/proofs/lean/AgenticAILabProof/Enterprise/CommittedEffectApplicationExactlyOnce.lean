-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure

namespace AgenticAILabProof.Enterprise.CommittedEffectApplicationExactlyOnce

open AgenticAILabProof.Enterprise.BundleEvidenceBinding
open AgenticAILabProof.Enterprise.EffectDomainCoverage
open AgenticAILabProof.Enterprise.SourceBoundCompositionalEffectClosure

def sourceBoundEffectOccurrenceCount
    (effectId : EffectId)
    (traceReceipt : SourceBoundEffectExecutionTraceReceipt) : Nat :=
  (traceReceipt.events.map SourceBoundEffectExecutionEvent.effectId).count effectId

def sourceBoundTraceExecutesUniverseExactlyOnce
    (witness : SourceBoundCompositionalEffectWitness)
    (traceReceipt : SourceBoundEffectExecutionTraceReceipt) : Prop :=
  witness.effectUniverse.Nodup ∧
    ∀ effectId ∈ witness.effectUniverse,
      sourceBoundEffectOccurrenceCount effectId traceReceipt = 1

structure SourceBoundCommittedEffectExactlyOnceClosed
    (request : SourceBoundCompositionRequestSubject)
    (activeFenceToken : Nat)
    (registryValid : SourceBoundCompositionRegistryValid)
    (witnessValid : SourceBoundCompositionalEffectWitnessValid)
    (bindingValid : SourceBoundObjectBindingValid)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (traceOwnerValid : SourceBoundExecutionTraceOwnerValid)
    (registry : SourceBoundCompositionRegistry)
    (roots : SourceBoundUseCompositionProfiles)
    (witness : SourceBoundCompositionalEffectWitness)
    (resolutionReceipts : List ResolutionReceipt)
    (traceReceipt : SourceBoundEffectExecutionTraceReceipt) : Prop where
  sourceBoundEffectCloses :
    SourceBoundEffectClosure
      request
      activeFenceToken
      registryValid
      witnessValid
      bindingValid
      resolutionReceiptValid
      traceOwnerValid
      registry
      roots
      witness
      resolutionReceipts
      traceReceipt
  effectUniverseExecutesExactlyOnce :
    sourceBoundTraceExecutesUniverseExactlyOnce witness traceReceipt

structure SourceBoundCommittedEffectExactlyOnceEvidence where
  request : SourceBoundCompositionRequestSubject
  activeFenceToken : Nat
  registryValid : SourceBoundCompositionRegistryValid
  witnessValid : SourceBoundCompositionalEffectWitnessValid
  bindingValid : SourceBoundObjectBindingValid
  resolutionReceiptValid : ResolutionReceiptValid
  traceOwnerValid : SourceBoundExecutionTraceOwnerValid
  registry : SourceBoundCompositionRegistry
  roots : SourceBoundUseCompositionProfiles
  witness : SourceBoundCompositionalEffectWitness
  resolutionReceipts : List ResolutionReceipt
  traceReceipt : SourceBoundEffectExecutionTraceReceipt
  closed :
    SourceBoundCommittedEffectExactlyOnceClosed
      request
      activeFenceToken
      registryValid
      witnessValid
      bindingValid
      resolutionReceiptValid
      traceOwnerValid
      registry
      roots
      witness
      resolutionReceipts
      traceReceipt

theorem closedCommittedEffectsPreserveSourceBoundComposition
    {request : SourceBoundCompositionRequestSubject}
    {activeFenceToken : Nat}
    {registryValid : SourceBoundCompositionRegistryValid}
    {witnessValid : SourceBoundCompositionalEffectWitnessValid}
    {bindingValid : SourceBoundObjectBindingValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {traceOwnerValid : SourceBoundExecutionTraceOwnerValid}
    {registry : SourceBoundCompositionRegistry}
    {roots : SourceBoundUseCompositionProfiles}
    {witness : SourceBoundCompositionalEffectWitness}
    {resolutionReceipts : List ResolutionReceipt}
    {traceReceipt : SourceBoundEffectExecutionTraceReceipt}
    (closed :
      SourceBoundCommittedEffectExactlyOnceClosed
        request
        activeFenceToken
        registryValid
        witnessValid
        bindingValid
        resolutionReceiptValid
        traceOwnerValid
        registry
        roots
        witness
        resolutionReceipts
        traceReceipt) :
    SourceBoundEffectClosure
      request
      activeFenceToken
      registryValid
      witnessValid
      bindingValid
      resolutionReceiptValid
      traceOwnerValid
      registry
      roots
      witness
      resolutionReceipts
      traceReceipt :=
  closed.sourceBoundEffectCloses

theorem everyDeclaredEffectExecutesExactlyOnce
    {request : SourceBoundCompositionRequestSubject}
    {activeFenceToken : Nat}
    {registryValid : SourceBoundCompositionRegistryValid}
    {witnessValid : SourceBoundCompositionalEffectWitnessValid}
    {bindingValid : SourceBoundObjectBindingValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {traceOwnerValid : SourceBoundExecutionTraceOwnerValid}
    {registry : SourceBoundCompositionRegistry}
    {roots : SourceBoundUseCompositionProfiles}
    {witness : SourceBoundCompositionalEffectWitness}
    {resolutionReceipts : List ResolutionReceipt}
    {traceReceipt : SourceBoundEffectExecutionTraceReceipt}
    (closed :
      SourceBoundCommittedEffectExactlyOnceClosed
        request
        activeFenceToken
        registryValid
        witnessValid
        bindingValid
        resolutionReceiptValid
        traceOwnerValid
        registry
        roots
        witness
        resolutionReceipts
        traceReceipt) :
    ∀ effectId ∈ witness.effectUniverse,
      sourceBoundEffectOccurrenceCount effectId traceReceipt = 1 :=
  closed.effectUniverseExecutesExactlyOnce.2

theorem evidenceExecutesEveryDeclaredEffectExactlyOnce
    (evidence : SourceBoundCommittedEffectExactlyOnceEvidence) :
    ∀ effectId ∈ evidence.witness.effectUniverse,
      sourceBoundEffectOccurrenceCount effectId evidence.traceReceipt = 1 :=
  everyDeclaredEffectExecutesExactlyOnce evidence.closed

theorem everyRuntimeEffectBelongsToDeclaredUniverse
    {request : SourceBoundCompositionRequestSubject}
    {activeFenceToken : Nat}
    {registryValid : SourceBoundCompositionRegistryValid}
    {witnessValid : SourceBoundCompositionalEffectWitnessValid}
    {bindingValid : SourceBoundObjectBindingValid}
    {resolutionReceiptValid : ResolutionReceiptValid}
    {traceOwnerValid : SourceBoundExecutionTraceOwnerValid}
    {registry : SourceBoundCompositionRegistry}
    {roots : SourceBoundUseCompositionProfiles}
    {witness : SourceBoundCompositionalEffectWitness}
    {resolutionReceipts : List ResolutionReceipt}
    {traceReceipt : SourceBoundEffectExecutionTraceReceipt}
    (closed :
      SourceBoundCommittedEffectExactlyOnceClosed
        request
        activeFenceToken
        registryValid
        witnessValid
        bindingValid
        resolutionReceiptValid
        traceOwnerValid
        registry
        roots
        witness
        resolutionReceipts
        traceReceipt)
    (event : SourceBoundEffectExecutionEvent)
    (eventInTrace : event ∈ traceReceipt.events) :
    event.effectId ∈ witness.effectUniverse :=
  closedSourceBoundCompositionCoversEveryRuntimeEvent
    request
    activeFenceToken
    registryValid
    witnessValid
    bindingValid
    resolutionReceiptValid
    traceOwnerValid
    registry
    roots
    witness
    resolutionReceipts
    traceReceipt
    closed.sourceBoundEffectCloses
    event
    eventInTrace

end AgenticAILabProof.Enterprise.CommittedEffectApplicationExactlyOnce
