// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite abstraction of Agent-selected queries, not an Agent decision policy.
module TrajectoryClueScope {
  const Mutation: str
  type State = {
    source: int, rules: int, verified: bool, negative: bool,
    hypothesis: bool, near: bool, negativeNear: bool,
    positiveContent: int, positiveReceiptContent: int,
    receipt: bool, negativeReceipt: bool, complete: bool, interrupted: bool,
    viewPresent: bool, viewSource: int, viewRules: int, viewScope: int,
    viewCurrent: bool, viewOwnerKind: str, supported: bool, counterevidence: bool,
    positiveReference: int, negativeReference: int,
    refuted: bool, unknown: bool,
    scopeRegression: bool, history: int, retained: int,
    wideAvailable: bool, choiceSelected: bool
  }
  var q: State
  action init = q' = {
    source: 0, rules: 0, verified: false, negative: false,
    hypothesis: false, near: true, negativeNear: true,
    positiveContent: 0, positiveReceiptContent: 0,
    receipt: false, negativeReceipt: false,
    complete: false, interrupted: false,
    viewPresent: false, viewSource: -1, viewRules: -1, viewScope: -1,
    viewCurrent: false, viewOwnerKind: "none", supported: false, counterevidence: false,
    positiveReference: -1, negativeReference: -1,
    refuted: false, unknown: false,
    scopeRegression: false, history: 0, retained: 0,
    wideAvailable: true, choiceSelected: false
  }
  action Hypothesize = all {q.history < 2,
    q' = {...q, hypothesis: true, history: q.history + 1,
      retained: q.retained + 1}}
  action AdmitNear = all {q.source < 2 and q.history < 2,
    q' = {...q, source: q.source + 1, verified: true, near: true,
      receipt: true, positiveReceiptContent: q.positiveContent,
      viewCurrent: false, history: q.history + 1,
      retained: q.retained + 1}}
  action AdmitFar = all {q.source < 2 and q.history < 2,
    q' = {...q, source: q.source + 1, verified: true, near: false,
      receipt: true, positiveReceiptContent: q.positiveContent,
      viewCurrent: false, history: q.history + 1,
      retained: q.retained + 1}}
  action AdmitNegativeNear = all {q.source < 2 and q.history < 2,
    q' = {...q, source: q.source + 1, negative: true,
      negativeNear: true, negativeReceipt: true, viewCurrent: false,
      history: q.history + 1, retained: q.retained + 1}}
  action AdmitNegativeFar = all {q.source < 2 and q.history < 2,
    q' = {...q, source: q.source + 1, negative: true,
      negativeNear: false, negativeReceipt: true, viewCurrent: false,
      history: q.history + 1, retained: q.retained + 1}}
  action Withdraw = all {q.verified and q.source < 2,
    q' = {...q, source: q.source + 1, verified: false, receipt: false,
      viewCurrent: Mutation == "accept-stale"}}
  action LoseReceipt = all {q.receipt,
    q' = {...q, receipt: false,
      viewCurrent: Mutation == "accept-missing-receipt"}}
  action ReplaceClueContent = all {q.verified and q.source < 2 and
    q.positiveContent < 1,
    q' = {...q, source: q.source + 1,
      positiveContent: q.positiveContent + 1, viewCurrent: false}}
  action LoseNegativeReceipt = all {q.negativeReceipt,
    q' = {...q, negativeReceipt: false,
      viewCurrent: Mutation == "accept-missing-receipt"}}
  action ReviseRules = all {q.rules < 1,
    q' = {...q, rules: q.rules + 1,
      viewCurrent: Mutation == "accept-stale"}}
  action SealDomain = all {q.source < 2,
    q' = {...q, source: q.source + 1, complete: true,
      viewCurrent: false}}
  action QueryNarrow = all {not(q.interrupted),
    q' = {...q, viewPresent: true, viewSource: q.source,
      viewOwnerKind: if (Mutation == "mix-catalog-source") "catalog" else "clue-source",
      viewRules: q.rules, viewScope: 0, viewCurrent: true,
      supported: (q.verified and q.receipt and q.near and
        (q.positiveContent == q.positiveReceiptContent or
          Mutation == "inherit-old-receipt")) or
        (Mutation == "promote-hypothesis" and q.hypothesis),
      positiveReference: if (q.verified and q.receipt and q.near and
        q.positiveContent == q.positiveReceiptContent) 1 else -1,
      counterevidence: (q.negative and q.negativeReceipt and
        q.negativeNear) and Mutation != "hide-counterevidence",
      negativeReference: if (q.negative and q.negativeReceipt and
        q.negativeNear and Mutation != "hide-counterevidence")
        (if (Mutation == "misattribute-counter") 1 else 2) else -1,
      refuted: Mutation == "negate-absence" and not(q.verified and q.near),
      unknown: not(q.verified and q.receipt and q.near and
        q.positiveContent == q.positiveReceiptContent) and
        not(q.negative and q.negativeReceipt and q.negativeNear) and
        Mutation != "promote-hypothesis" and Mutation != "negate-absence",
      wideAvailable: Mutation != "close-scope",
      choiceSelected: Mutation == "force-choice"}}
  action QueryWide = all {not(q.interrupted) and q.wideAvailable,
    q' = {...q, viewPresent: true, viewSource: q.source,
      viewOwnerKind: if (Mutation == "mix-catalog-source") "catalog" else "clue-source",
      viewRules: q.rules, viewScope: 1, viewCurrent: true,
      supported: (q.verified and q.receipt and
        (q.positiveContent == q.positiveReceiptContent or
          Mutation == "inherit-old-receipt") and
        Mutation != "drop-on-expand") or
        (Mutation == "promote-hypothesis" and q.hypothesis),
      positiveReference: if (q.verified and q.receipt and
        q.positiveContent == q.positiveReceiptContent and
        Mutation != "drop-on-expand") 1 else -1,
      counterevidence: (q.negative and q.negativeReceipt) and
        Mutation != "hide-counterevidence" and Mutation != "drop-on-expand",
      negativeReference: if (q.negative and q.negativeReceipt and
        Mutation != "hide-counterevidence" and Mutation != "drop-on-expand")
        (if (Mutation == "misattribute-counter") 1 else 2) else -1,
      refuted: (q.complete and not(q.verified and q.receipt and
        q.positiveContent == q.positiveReceiptContent)) or
        (Mutation == "negate-absence" and not(q.verified)),
      unknown: not(q.verified and q.receipt and
        q.positiveContent == q.positiveReceiptContent) and
        not(q.negative and q.negativeReceipt) and not(q.complete) and
        Mutation != "promote-hypothesis" and Mutation != "negate-absence",
      scopeRegression: q.scopeRegression or
        (q.viewCurrent and q.viewScope == 0 and
          (q.supported or q.counterevidence) and
          Mutation == "drop-on-expand"),
      choiceSelected: Mutation == "force-choice"}}
  action Interrupt = q' = {...q, interrupted: true, viewCurrent: false}
  action Resume = q' = {...q, interrupted: false,
    retained: if (Mutation == "drop-history") 0 else q.retained}
  action step = any {Hypothesize, AdmitNear, AdmitFar,
    AdmitNegativeNear, AdmitNegativeFar, Withdraw,
    LoseReceipt, LoseNegativeReceipt, ReplaceClueContent,
    ReviseRules, SealDomain,
    QueryNarrow, QueryWide,
    Interrupt, Resume}
  val CurrentBinding = not(q.viewCurrent) or
    (q.viewPresent and q.viewOwnerKind == "clue-source" and
      q.viewSource == q.source and q.viewRules == q.rules and
      not(q.interrupted) and (not(q.supported) or q.receipt) and
      (not(q.counterevidence) or q.negativeReceipt))
  val ObservationAuthority = not(q.viewCurrent and q.supported) or
    (q.verified and q.receipt and
      q.positiveContent == q.positiveReceiptContent)
  val CounterAuthority = not(q.viewCurrent and q.counterevidence) or
    (q.negative and q.negativeReceipt)
  val CorrectReferences = not(q.viewCurrent) or
    ((not(q.supported) or q.positiveReference == 1) and
      (not(q.counterevidence) or q.negativeReference == 2))
  val ConflictVisible = not(q.viewCurrent and q.verified and q.receipt and
    q.positiveContent == q.positiveReceiptContent and
    q.negative and q.negativeReceipt and
    (q.viewScope == 1 or (q.near and q.negativeNear))) or
    (q.supported and q.counterevidence)
  val OpenWorld = not(q.viewCurrent and q.refuted) or
    (q.complete and q.viewScope == 1)
  val UnknownIsUnproved = not(q.unknown and
    (q.supported or q.counterevidence or q.refuted))
  val ScopeConservative = not(q.scopeRegression)
  val OpenExploration = q.wideAvailable and not(q.choiceSelected)
  val DurableHistory = q.retained == q.history
  val Safety = CurrentBinding and ObservationAuthority and CounterAuthority
    and CorrectReferences
    and ConflictVisible and OpenWorld and UnknownIsUnproved and
    ScopeConservative and OpenExploration and DurableHistory
}
module TrajectoryClueScopeHealthy {
  import TrajectoryClueScope(Mutation = "none").*
}
module TrajectoryClueScopeHypothesis {
  import TrajectoryClueScope(Mutation = "promote-hypothesis").*
}
module TrajectoryClueScopeAbsence {
  import TrajectoryClueScope(Mutation = "negate-absence").*
}
module TrajectoryClueScopeStale {
  import TrajectoryClueScope(Mutation = "accept-stale").*
}
module TrajectoryClueScopeReceipt {
  import TrajectoryClueScope(Mutation = "accept-missing-receipt").*
}
module TrajectoryClueScopeExpand {
  import TrajectoryClueScope(Mutation = "drop-on-expand").*
}
module TrajectoryClueScopeClosed {
  import TrajectoryClueScope(Mutation = "close-scope").*
}
module TrajectoryClueScopeChoice {
  import TrajectoryClueScope(Mutation = "force-choice").*
}
module TrajectoryClueScopeHistory {
  import TrajectoryClueScope(Mutation = "drop-history").*
}
module TrajectoryClueScopeCounterevidence {
  import TrajectoryClueScope(Mutation = "hide-counterevidence").*
}
module TrajectoryClueScopeAttribution {
  import TrajectoryClueScope(Mutation = "misattribute-counter").*
}
module TrajectoryClueScopeContent {
  import TrajectoryClueScope(Mutation = "inherit-old-receipt").*
}
