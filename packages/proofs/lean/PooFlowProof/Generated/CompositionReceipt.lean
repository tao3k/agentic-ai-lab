-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.PooC4.CompositionReceipt

namespace PooFlowProof.PooC4

def GeneratedLangGraphCompositionReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := true
  overridesScopedOk := true
  modulesOrderedOk := true
  scenarioGateOk := true
  noRuntimeExecution := true

theorem GeneratedLangGraphCompositionReceiptAccepted :
    compositionReceiptAccepted GeneratedLangGraphCompositionReceiptFacts :=
  compositionReceiptAcceptedByAllOk
    GeneratedLangGraphCompositionReceiptFacts
    rfl
    rfl
    rfl
    rfl
    rfl

def GeneratedCompositionBadOverrideReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := true
  overridesScopedOk := false
  modulesOrderedOk := true
  scenarioGateOk := true
  noRuntimeExecution := true

theorem GeneratedCompositionBadOverrideReceiptRejected :
    ¬ compositionReceiptAccepted GeneratedCompositionBadOverrideReceiptFacts :=
  compositionReceiptRejectedByOverrideScope
    GeneratedCompositionBadOverrideReceiptFacts
    rfl

def GeneratedCompositionBadProfileRefsReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := false
  overridesScopedOk := true
  modulesOrderedOk := true
  scenarioGateOk := true
  noRuntimeExecution := true

theorem GeneratedCompositionBadProfileRefsReceiptRejected :
    ¬ compositionReceiptAccepted GeneratedCompositionBadProfileRefsReceiptFacts :=
  compositionReceiptRejectedByProfileRefs
    GeneratedCompositionBadProfileRefsReceiptFacts
    rfl

def GeneratedCompositionBadModuleOrderReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := true
  overridesScopedOk := true
  modulesOrderedOk := false
  scenarioGateOk := true
  noRuntimeExecution := true

theorem GeneratedCompositionBadModuleOrderReceiptRejected :
    ¬ compositionReceiptAccepted GeneratedCompositionBadModuleOrderReceiptFacts :=
  compositionReceiptRejectedByModuleOrder
    GeneratedCompositionBadModuleOrderReceiptFacts
    rfl

def GeneratedCompositionBadScenarioGateReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := true
  overridesScopedOk := true
  modulesOrderedOk := true
  scenarioGateOk := false
  noRuntimeExecution := true

theorem GeneratedCompositionBadScenarioGateReceiptRejected :
    ¬ compositionReceiptAccepted GeneratedCompositionBadScenarioGateReceiptFacts :=
  compositionReceiptRejectedByScenarioGate
    GeneratedCompositionBadScenarioGateReceiptFacts
    rfl

def GeneratedCompositionRuntimeExecutionReceiptFacts : CompositionReceiptFacts where
  profileRefsOk := true
  overridesScopedOk := true
  modulesOrderedOk := true
  scenarioGateOk := true
  noRuntimeExecution := false

theorem GeneratedCompositionRuntimeExecutionReceiptRejected :
    ¬ compositionReceiptAccepted GeneratedCompositionRuntimeExecutionReceiptFacts :=
  compositionReceiptRejectedByRuntimeExecution
    GeneratedCompositionRuntimeExecutionReceiptFacts
    rfl

end PooFlowProof.PooC4
