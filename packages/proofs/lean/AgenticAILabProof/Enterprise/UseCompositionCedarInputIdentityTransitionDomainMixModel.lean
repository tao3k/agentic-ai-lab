-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionDomainMixModel

structure DomainWatermark where
  publicationDomainIdentity : Nat
  authorityIdentity : Nat
  minimumGeneration : Nat
  deriving DecidableEq, Repr

structure DomainBoundContext where
  authorityIdentity : Nat
  generation : Nat
  deriving DecidableEq, Repr

def watermarkAdmitsContext
    (watermark : DomainWatermark)
    (context : DomainBoundContext) : Prop :=
  watermark.authorityIdentity = context.authorityIdentity ∧
    watermark.minimumGeneration ≤ context.generation

def successorWatermark : DomainWatermark where
  publicationDomainIdentity := 101
  authorityIdentity := 17
  minimumGeneration := 4

def checkpointWatermark : DomainWatermark where
  publicationDomainIdentity := 202
  authorityIdentity := 17
  minimumGeneration := 4

def sharedContext : DomainBoundContext where
  authorityIdentity := 17
  generation := 4

theorem independentWatermarksAllowCrossDomainContextMix :
    watermarkAdmitsContext successorWatermark sharedContext ∧
      watermarkAdmitsContext checkpointWatermark sharedContext ∧
      successorWatermark.publicationDomainIdentity ≠
        checkpointWatermark.publicationDomainIdentity := by
  simp [watermarkAdmitsContext, successorWatermark, checkpointWatermark,
    sharedContext]

theorem exactWatermarkBindingRejectsCrossDomainMix :
    successorWatermark ≠ checkpointWatermark := by
  decide

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionDomainMixModel
