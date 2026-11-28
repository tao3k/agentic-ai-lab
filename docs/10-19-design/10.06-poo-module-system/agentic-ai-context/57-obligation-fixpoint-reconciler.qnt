// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 57: Post-ReAct Declarative Obligation-Fixpoint Reconciler
// (ASCENT × FunFlow × POO × Temporal Causality × Stateless Typed SynthesisOracle).
module AscentObligationFixpointReconciler {
  type State = {
    sourceCut: int,
    readyDetTasks: int,
    holePremiseDigest: int,
    attemptedPremiseDigest: int,
    oracleInvocationsOnSamePremise: int,
    oracleCalledWithDetPending: bool,
    rawToolCallAdmitted: bool,
    competingHypothesesCount: int,
    collapsedCompetingHypotheses: bool,
    independentCasRetained: bool,
    quiescent: bool,
  }

  var s57: State

  action init = all {
    s57' = {
      sourceCut: 1,
      readyDetTasks: 2,
      holePremiseDigest: 1,
      attemptedPremiseDigest: 0,
      oracleInvocationsOnSamePremise: 0,
      oracleCalledWithDetPending: false,
      rawToolCallAdmitted: false,
      competingHypothesesCount: 2,
      collapsedCompetingHypotheses: false,
      independentCasRetained: true,
      quiescent: false,
    }
  }

  // Deterministic FunFlow frontier executes first with 0 LLM calls
  action runDeterministicFunflowTask = all {
    s57.readyDetTasks > 0,
    s57' = {
      ...s57,
      readyDetTasks: s57.readyDetTasks - 1,
      quiescent: false,
    }
  }

  // Stateless typed SynthesisOracle runs ONLY when deterministic frontier == 0
  // AND (hole, premiseDigest) has NOT yet been attempted!
  action invokeTypedSynthesisOracleOnce = all {
    s57.readyDetTasks == 0,
    s57.attemptedPremiseDigest != s57.holePremiseDigest,
    s57' = {
      ...s57,
      attemptedPremiseDigest: s57.holePremiseDigest,
      oracleInvocationsOnSamePremise: 1,
      quiescent: false,
    }
  }

  // Natural Datalog fixed-point quiescence: no det tasks & hole already attempted
  action reachQuiescentFixedPoint = all {
    s57.readyDetTasks == 0,
    s57.attemptedPremiseDigest == s57.holePremiseDigest,
    not(s57.quiescent),
    s57' = { ...s57, quiescent: true }
  }

  // Event-driven premise retraction advances cut and updates ONLY dependent premise digest,
  // preserving independent CAS artifacts and cleanly reopening only the affected hole.
  action eventRetractDependentPremise = all {
    s57.sourceCut < 2,
    s57.quiescent,
    s57' = {
      ...s57,
      sourceCut: 2,
      holePremiseDigest: 2,
      oracleInvocationsOnSamePremise: 0,
      independentCasRetained: true,
      quiescent: false,
    }
  }

  action step = any {
    runDeterministicFunflowTask,
    invokeTypedSynthesisOracleOnce,
    reachQuiescentFixedPoint,
    eventRetractDependentPremise,
  }

  // Negative-control fault injections reproducing all 4 ReAct anti-patterns
  action buggyReinvokeOracleOnUnchangedPremise = all {
    s57.attemptedPremiseDigest == s57.holePremiseDigest,
    s57' = { ...s57, oracleInvocationsOnSamePremise: s57.oracleInvocationsOnSamePremise + 1 }
  }

  action buggyCallLlmWhileDetTasksReady = all {
    s57.readyDetTasks > 0,
    s57' = { ...s57, oracleCalledWithDetPending: true }
  }

  action buggyAdmitRawSingleStepToolCall = all {
    not(s57.rawToolCallAdmitted),
    s57' = { ...s57, rawToolCallAdmitted: true }
  }

  action buggyCollapseCompetingHypotheses = all {
    s57.competingHypothesesCount >= 2,
    s57' = { ...s57, collapsedCompetingHypotheses: true }
  }

  // Four bidirectional safety invariants mapped in SysML
  val sameHolePremiseNeverReinvokesOracle =
    s57.oracleInvocationsOnSamePremise <= 1

  val llmOracleNeverCalledWhileDeterministicFrontierNonEmpty =
    not(s57.oracleCalledWithDetPending)

  val rawSingleStepToolCallNeverAdmittedFromOracle =
    not(s57.rawToolCallAdmitted)

  val competingHypothesesNeverCollapsedWhenUnrefuted =
    not(s57.collapsedCompetingHypotheses)

  val safety = and {
    sameHolePremiseNeverReinvokesOracle,
    llmOracleNeverCalledWhileDeterministicFrontierNonEmpty,
    rawSingleStepToolCallNeverAdmittedFromOracle,
    competingHypothesesNeverCollapsedWhenUnrefuted,
  }

  // Positive witnesses
  run safeDetFirstAndFixedPointTest =
    init
      .then(runDeterministicFunflowTask)
      .then(runDeterministicFunflowTask)
      .then(invokeTypedSynthesisOracleOnce)
      .then(reachQuiescentFixedPoint)
      .expect(safety and s57.quiescent and s57.readyDetTasks == 0 and s57.independentCasRetained)

  run safeEventRetractionAndReconvergenceTest =
    init
      .then(runDeterministicFunflowTask)
      .then(runDeterministicFunflowTask)
      .then(invokeTypedSynthesisOracleOnce)
      .then(reachQuiescentFixedPoint)
      .then(eventRetractDependentPremise)
      .then(invokeTypedSynthesisOracleOnce)
      .then(reachQuiescentFixedPoint)
      .expect(safety and s57.quiescent and s57.sourceCut == 2 and s57.independentCasRetained)

  // Negative-control counterexamples (ITF replay witnesses)
  run duplicateOraclePremiseCounterexampleTest =
    init
      .then(runDeterministicFunflowTask)
      .then(runDeterministicFunflowTask)
      .then(invokeTypedSynthesisOracleOnce)
      .then(buggyReinvokeOracleOnUnchangedPremise)
      .expect(not(sameHolePremiseNeverReinvokesOracle))

  run llmPreemptsDetFrontierCounterexampleTest =
    init
      .then(buggyCallLlmWhileDetTasksReady)
      .expect(not(llmOracleNeverCalledWhileDeterministicFrontierNonEmpty))

  run rawToolCallOracleCounterexampleTest =
    init
      .then(buggyAdmitRawSingleStepToolCall)
      .expect(not(rawSingleStepToolCallNeverAdmittedFromOracle))

  run greedyHypothesisCollapseCounterexampleTest =
    init
      .then(buggyCollapseCompetingHypotheses)
      .expect(not(competingHypothesesNeverCollapsedWhenUnrefuted))
}
