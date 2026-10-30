// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite read protocol; Agent reasoning and native evidence are external.
module TrajectoryProgressiveAccess {
  const Mutation: str
  type State = {source: int, prefix: int, packetSource: int, packetPrefix: int,
    packetPresent: bool, currentAccepted: bool, receiptPresent: bool,
    reviewed: bool, receiptSource: int, receiptPrefix: int,
    resultVisible: bool, attempts: int, retained: int, interrupted: bool,
    briefHasHistory: bool, focusAvailable: bool, exactAvailable: bool,
    choiceSelected: bool}
  var q: State
  action init = q' = {source: 0, prefix: 0, packetSource: -1,
    packetPrefix: -1, packetPresent: false, currentAccepted: false,
    receiptPresent: false, reviewed: false, receiptSource: -1,
    receiptPrefix: -1, resultVisible: false,
    attempts: 0, retained: 0,
    interrupted: false, briefHasHistory: false, focusAvailable: true,
    exactAvailable: true, choiceSelected: false}
  action Append = all {q.prefix < 2,
    q' = {...q, prefix: q.prefix + 1, attempts: q.attempts + 1,
      retained: q.retained + 1,
      currentAccepted: false, resultVisible: false}}
  action Brief = q' = {...q, packetSource: q.source,
    packetPrefix: q.prefix, packetPresent: true,
    currentAccepted: false, resultVisible: false,
    briefHasHistory: Mutation == "full-handoff",
    focusAvailable: Mutation != "hide-focus",
    exactAvailable: Mutation != "hide-exact",
    choiceSelected: Mutation == "force-choice"}
  action Focus = all {q.packetPresent,
    q' = {...q, currentAccepted: (q.packetSource == q.source and
      q.packetPrefix == q.prefix) or Mutation == "accept-stale",
      resultVisible: q.receiptPresent and q.reviewed and
        q.receiptSource == q.source and q.receiptPrefix == q.prefix and
        ((q.packetSource == q.source and q.packetPrefix == q.prefix) or
          Mutation == "accept-stale")}}
  action Exact = all {q.packetPresent,
    q' = {...q, currentAccepted: (q.packetSource == q.source and
      q.packetPrefix == q.prefix) or Mutation == "accept-stale",
      resultVisible: (q.receiptPresent or Mutation == "missing-receipt") and
        q.reviewed and q.receiptSource == q.source and
        q.receiptPrefix == q.prefix and
        q.packetSource == q.source and q.packetPrefix == q.prefix}}
  action SupplyReceipt = q' = {...q, receiptPresent: true, reviewed: false,
    resultVisible: false, receiptSource: q.source, receiptPrefix: q.prefix}
  action ReviewReceipt = all {q.receiptPresent,
    q' = {...q, reviewed: true}}
  action LoseReceipt = all {q.receiptPresent,
    q' = {...q, receiptPresent: false, resultVisible: false}}
  action ReplaceSource = all {q.source < 1,
    q' = {...q, source: q.source + 1, currentAccepted: false,
      resultVisible: false, receiptPresent: false, reviewed: false}}
  action ReplaceSameCount = all {q.prefix < 2,
    q' = {...q, prefix: q.prefix + 1, currentAccepted: false,
      resultVisible: false, receiptPresent: false, reviewed: false}}
  action Interrupt = q' = {...q, interrupted: true,
    currentAccepted: false, resultVisible: false}
  action Resume = q' = {...q, interrupted: false,
    retained: if (Mutation == "drop-history") 0 else q.retained}
  action step = any {Append, Brief, Focus, Exact, SupplyReceipt, ReviewReceipt,
    LoseReceipt,
    ReplaceSource, ReplaceSameCount, Interrupt, Resume}
  val CurrentRead = not(q.currentAccepted) or
    (q.packetPresent and q.packetSource == q.source and q.packetPrefix == q.prefix)
  val SupportedResult = not(q.resultVisible) or
    (q.receiptPresent and q.reviewed and q.currentAccepted and
      q.receiptSource == q.source and q.receiptPrefix == q.prefix)
  val ThinHandoff = not(q.briefHasHistory)
  val OpenReads = q.focusAvailable and q.exactAvailable
  val AgentOwnsChoice = not(q.choiceSelected)
  val DurablePrefix = q.retained == q.attempts
  val Safety = CurrentRead and SupportedResult and ThinHandoff and
    OpenReads and AgentOwnsChoice and DurablePrefix
}

module TrajectoryProgressiveAccessHealthy {
  import TrajectoryProgressiveAccess(Mutation = "none").*
}
module TrajectoryProgressiveAccessStale {
  import TrajectoryProgressiveAccess(Mutation = "accept-stale").*
}
module TrajectoryProgressiveAccessReceipt {
  import TrajectoryProgressiveAccess(Mutation = "missing-receipt").*
}
module TrajectoryProgressiveAccessHistory {
  import TrajectoryProgressiveAccess(Mutation = "drop-history").*
}
module TrajectoryProgressiveAccessHandoff {
  import TrajectoryProgressiveAccess(Mutation = "full-handoff").*
}
module TrajectoryProgressiveAccessFocus {
  import TrajectoryProgressiveAccess(Mutation = "hide-focus").*
}
module TrajectoryProgressiveAccessChoice {
  import TrajectoryProgressiveAccess(Mutation = "force-choice").*
}
