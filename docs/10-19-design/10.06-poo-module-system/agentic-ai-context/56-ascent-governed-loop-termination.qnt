// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//
// Slice 56: ASCENT-Governed Loop Engine Termination, Anti-Oscillation,
// Safety-Dominance Lattice & Absorbing Halt Closure.
module AscentGovernedLoopTermination {
  type State = {
    initialBudget: int,
    stepBudgetRemaining: int,
    stepsTaken: int,
    remainingFrontier: int,
    exactCycleDetected: bool,
    oscillationDetected: bool,
    repeatedFailures: int,
    stallStreak: int,
    governanceBlocked: bool,
    halted: bool,
    humanReopenEndorsed: bool,
    admittedAfterCycle: bool,
    admittedAfterGovBlock: bool,
    selfResetSucceeded: bool,
  }

  var s56: State

  action init = all {
    s56' = {
      initialBudget: 4,
      stepBudgetRemaining: 4,
      stepsTaken: 0,
      remainingFrontier: 3,
      exactCycleDetected: false,
      oscillationDetected: false,
      repeatedFailures: 0,
      stallStreak: 0,
      governanceBlocked: false,
      halted: false,
      humanReopenEndorsed: false,
      admittedAfterCycle: false,
      admittedAfterGovBlock: false,
      selfResetSucceeded: false,
    }
  }

  // Admitted progress turn: strictly decrements budget and frontier
  action admitProgressTurn = all {
    not(s56.halted),
    not(s56.governanceBlocked),
    not(s56.exactCycleDetected),
    not(s56.oscillationDetected),
    s56.repeatedFailures < 2,
    s56.stallStreak < 2,
    s56.stepBudgetRemaining > 0,
    s56.remainingFrontier > 0,
    s56' = {
      ...s56,
      stepBudgetRemaining: s56.stepBudgetRemaining - 1,
      stepsTaken: s56.stepsTaken + 1,
      remainingFrontier: s56.remainingFrontier - 1,
      stallStreak: 0,
      repeatedFailures: 0,
    }
  }

  // Zero-progress turn (novel state, frontier unchanged) increments stall streak
  action admitZeroProgressTurn = all {
    not(s56.halted),
    not(s56.governanceBlocked),
    not(s56.exactCycleDetected),
    not(s56.oscillationDetected),
    s56.repeatedFailures < 2,
    s56.stallStreak < 2,
    s56.stepBudgetRemaining > 0,
    s56.remainingFrontier > 0,
    s56' = {
      ...s56,
      stepBudgetRemaining: s56.stepBudgetRemaining - 1,
      stepsTaken: s56.stepsTaken + 1,
      stallStreak: s56.stallStreak + 1,
    }
  }

  // ASCENT detects exact state cycle or A <-> B oscillation and halts immediately
  action detectExactCycleAndHalt = all {
    not(s56.halted),
    s56' = { ...s56, exactCycleDetected: true, halted: true }
  }

  action detectOscillationAndHalt = all {
    not(s56.halted),
    s56' = { ...s56, oscillationDetected: true, halted: true }
  }

  // ASCENT detects stall threshold reached and halts immediately
  action detectStallAndHalt = all {
    not(s56.halted),
    s56.stallStreak >= 2,
    s56' = { ...s56, halted: true }
  }

  // Upstream governance block (MCP rug-pull, CaMeL sink, sandbox/Cedar) halts immediately
  action triggerGovernanceBlockAndHalt = all {
    not(s56.halted),
    s56' = { ...s56, governanceBlocked: true, halted: true }
  }

  // Clean fixed-point convergence when frontier reaches 0
  action convergeAndHalt = all {
    not(s56.halted),
    not(s56.governanceBlocked),
    s56.remainingFrontier == 0,
    s56' = { ...s56, halted: true }
  }

  // Budget exhaustion unconditionally halts
  action exhaustBudgetAndHalt = all {
    not(s56.halted),
    s56.stepBudgetRemaining == 0,
    s56' = { ...s56, halted: true }
  }

  // Non-self human reopen starts a fresh bounded epoch only when endorsed
  action humanEndorsedReopen = all {
    s56.halted,
    not(s56.humanReopenEndorsed),
    s56' = {
      ...s56,
      halted: false,
      governanceBlocked: false,
      exactCycleDetected: false,
      oscillationDetected: false,
      stallStreak: 0,
      repeatedFailures: 0,
      stepBudgetRemaining: 2,
      initialBudget: s56.stepsTaken + 2,
      humanReopenEndorsed: true,
    }
  }

  action step = any {
    admitProgressTurn,
    admitZeroProgressTurn,
    detectExactCycleAndHalt,
    detectOscillationAndHalt,
    detectStallAndHalt,
    triggerGovernanceBlockAndHalt,
    convergeAndHalt,
    exhaustBudgetAndHalt,
    humanEndorsedReopen,
  }

  // Negative-control fault injections reproducing all 4 infinite-loop & bypass bugs
  action buggyAdmitDespiteCycle = all {
    s56.exactCycleDetected or s56.oscillationDetected,
    s56' = { ...s56, admittedAfterCycle: true }
  }

  action buggyRetryDespiteGovernanceBlock = all {
    s56.governanceBlocked,
    s56' = { ...s56, admittedAfterGovBlock: true }
  }

  action buggySelfResetHaltedLoop = all {
    s56.halted,
    not(s56.humanReopenEndorsed),
    s56' = { ...s56, halted: false, selfResetSucceeded: true }
  }

  action buggyExceedBudget = all {
    s56.stepBudgetRemaining == 0,
    s56' = { ...s56, stepsTaken: s56.initialBudget + 1 }
  }

  // Four bidirectional safety invariants mapped in SysML
  val cycleOrOscillationNeverAdmitsNextStep =
    not(s56.admittedAfterCycle)

  val governanceBlockNeverOverriddenByRetry =
    not(s56.admittedAfterGovBlock)

  val haltedLoopNeverSelfResetsWithoutHumanReopen =
    not(s56.selfResetSucceeded)

  val stepsTakenNeverExceedsInitialBudget =
    s56.stepsTaken <= s56.initialBudget and s56.stepBudgetRemaining >= 0

  val safety = and {
    cycleOrOscillationNeverAdmitsNextStep,
    governanceBlockNeverOverriddenByRetry,
    haltedLoopNeverSelfResetsWithoutHumanReopen,
    stepsTakenNeverExceedsInitialBudget,
  }

  // Positive witnesses
  run safeConvergentLoopTest =
    init
      .then(admitProgressTurn)
      .then(admitProgressTurn)
      .then(admitProgressTurn)
      .then(convergeAndHalt)
      .expect(safety and s56.halted and s56.remainingFrontier == 0 and s56.stepsTaken == 3)

  run safeStallAndHumanReopenTest =
    init
      .then(admitZeroProgressTurn)
      .then(admitZeroProgressTurn)
      .then(detectStallAndHalt)
      .then(humanEndorsedReopen)
      .then(admitProgressTurn)
      .expect(safety and s56.humanReopenEndorsed and s56.stepsTaken == 3)

  // Negative-control counterexamples (ITF replay witnesses)
  run cycleAdmissionCounterexampleTest =
    init
      .then(detectOscillationAndHalt)
      .then(buggyAdmitDespiteCycle)
      .expect(not(cycleOrOscillationNeverAdmitsNextStep))

  run govBlockRetryCounterexampleTest =
    init
      .then(triggerGovernanceBlockAndHalt)
      .then(buggyRetryDespiteGovernanceBlock)
      .expect(not(governanceBlockNeverOverriddenByRetry))

  run selfResetCounterexampleTest =
    init
      .then(detectExactCycleAndHalt)
      .then(buggySelfResetHaltedLoop)
      .expect(not(haltedLoopNeverSelfResetsWithoutHumanReopen))

  run budgetOverflowCounterexampleTest =
    init
      .then(admitZeroProgressTurn)
      .then(admitZeroProgressTurn)
      .then(detectStallAndHalt)
      .then(humanEndorsedReopen)
      .then(admitProgressTurn)
      .then(admitProgressTurn)
      .then(buggyExceedBudget)
      .expect(not(stepsTakenNeverExceedsInitialBudget))
}
