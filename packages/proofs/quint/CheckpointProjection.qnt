// Caller-configured obligation graph, finite projection abstraction only.
// 0 -> 1 -> 2 are dependencies; 3 is independent, not a host CPU count.
module CheckpointProjection {
  const Mutation: str
  val required = Set(0, 1, 2, 3)
  pure def closure(g: Set[int]): Set[int] =
    g.union(if (g.contains(0)) Set(1, 2) else Set())
      .union(if (g.contains(1)) Set(2) else Set())
  type State = { ledger: Set[int], history: Set[int], changed: Set[int],
    material: bool, displayed: bool, current: bool, provenance: bool, traceGap: bool,
    support: Set[int], open: Set[int], choice: int, chosen: int }
  var q: State
  action init = q' = { ledger: Set(0), history: Set(0), changed: Set(),
    material: true, displayed: false, current: false, provenance: true, traceGap: false,
    support: Set(), open: required, choice: -1, chosen: -1 }
  pure def expected(h: Set[int], changed: Set[int]): Set[int] =
    h.exclude(closure(required.exclude(h).union(changed)))
  action receipt = { nondet r = required.oneOf();
    q' = {...q, ledger: q.ledger.union(Set(r)), history: q.history.union(Set(r)), current: false} }
  action change = { nondet r = required.oneOf();
    q' = {...q, changed: q.changed.union(Set(r)), current: false} }
  action clean = q' = {...q, material: false, current: false,
    history: if (Mutation == "erase-history") Set() else q.history}
  action restart = q' = {...q, current: false}
  action loseSource = q' = {...q, provenance: false, current: false}
  action restoreSource = q' = {...q, provenance: true, current: false}
  action choose = { nondet c = Set(-1, 0, 1, 2, 3, 9).oneOf();
    q' = {...q, choice: c, chosen: c} }
  action publish = {
    val base = expected(q.history, q.changed)
    val supported = if (Mutation == "promote-component" and base.contains(0)) base.union(Set(2))
      else if (Mutation == "display-completes") base.union(Set(2))
      else if (Mutation == "cache-erases-evidence" and not(q.material)) Set()
      else if (Mutation == "ignore-closure") q.history.exclude(q.changed)
      else base
    q' = {...q, support: supported,
      traceGap: if (Mutation == "hide-provenance-gap") false
        else not(q.provenance) and q.history.size() > 0,
      open: if (Mutation == "hide-open") Set() else required.exclude(supported),
      displayed: true, current: true,
      choice: if (Mutation == "force-choice") 0 else q.choice}
  }
  action step = any {receipt, change, clean, restart, loseSource, restoreSource, choose, publish}
  val PreserveLedger = q.history == q.ledger
  val ExactSupport = not(q.current) or q.support == expected(q.ledger, q.changed)
  val ExactOpen = not(q.current) or q.open == required.exclude(expected(q.ledger, q.changed))
  val GoalRequiresOwnReceipt = not(q.current) or not(q.support.contains(2)) or q.ledger.contains(2)
  val OpenChoice = q.choice == q.chosen
  val ProvenanceGapVisible = not(q.current) or q.traceGap == (not(q.provenance) and q.history.size() > 0)
  val Safety = PreserveLedger and ExactSupport and ExactOpen and GoalRequiresOwnReceipt and OpenChoice and ProvenanceGapVisible
}
