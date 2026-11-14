// Finite protocol abstraction, never a production search/cardinality limit.
module AnchoredEvidenceSlice {
  const Mutation: str
  val associations = Set({factor: 0, chain: 0}, {factor: 1, chain: 1})
  def seeds(exposed: Set[int], applicable: Set[int]): Set[int] =
    associations.filter(a => exposed.contains(a.factor) and applicable.contains(a.chain)).map(a => a.chain)
  def family(chains: Set[int]): Set[int] =
    Set(0, 1, 2, 3).filter(w => chains.contains(if (w < 2) 0 else 1))
  type State = {
    applicable: Set[int], exposed: Set[int], scope: Set[int], prior: Set[int],
    items: Set[int], added: Set[int], removed: Set[int], retained: Set[int],
    current: bool, receipts: bool, conditions: bool, declared: bool, evaluated: bool,
    sameWitness: bool, hintVerified: bool, queryOnly: bool, resolvedAnchors: Set[int],
    sufficient: bool, full: bool, transportFits: bool, acknowledged: bool, queried: bool, hit: bool, visible: Set[int],
    references: Set[int], expandable: Set[int], complete: bool, absent: bool,
    status: str, discovered: Set[int], selectedAction: bool, explorationOpen: bool
  }
  var q: State
  action init = q' = {
    applicable: Set(0, 1), exposed: Set(), scope: Set(), prior: Set(),
    items: Set(), added: Set(), removed: Set(), retained: Set(),
    current: true, receipts: true, conditions: true, declared: true, evaluated: true,
    sameWitness: true, hintVerified: true, queryOnly: false, resolvedAnchors: Set(),
    sufficient: true, full: true, transportFits: true, acknowledged: false, queried: false, hit: false, visible: Set(),
    references: Set(), expandable: Set(), complete: false, absent: false,
    status: "unqueried", discovered: Set(), selectedAction: false, explorationOpen: true
  }
  // Factor 2 is unassociated. 0/1 and 2/3 are opposite-polarity witness families.
  action Prepare = {
    nondet exposed = Set(Set(), Set(0), Set(1), Set(2), Set(0, 1)).oneOf()
    nondet applicable = Set(Set(), Set(0), Set(1), Set(0, 1)).oneOf()
    nondet prior = Set(Set(), Set(0, 1), Set(2, 3)).oneOf()
    nondet queryOnly = Set(false, true).oneOf()
    all {not(q.queried),
    q' = {...q, exposed: exposed, applicable: applicable, prior: prior, queryOnly: queryOnly}}
  }
  action Gap = {
    nondet which = Set("source", "receipt", "condition", "declaration", "evaluation", "capacity", "detail", "witness", "transport", "prior-delivery").oneOf()
    all {not(q.queried),
    q' = if (which == "source") {...q, current: false}
      else if (which == "receipt") {...q, receipts: false}
      else if (which == "condition") {...q, conditions: false}
      else if (which == "declaration") {...q, declared: false}
      else if (which == "evaluation") {...q, evaluated: false}
      else if (which == "witness") {...q, sameWitness: false}
      else if (which == "detail") {...q, full: false}
      else if (which == "transport") {...q, transportFits: false}
      else if (which == "prior-delivery") {...q, hintVerified: false}
      else {...q, sufficient: false}}
  }
  // Conjunctive anchors are witnessed by one ID/digest, not a claim-level union.
  def valid(s: State): bool = s.current and s.receipts and s.conditions and s.declared and s.evaluated and s.sameWitness
  // transportFits includes the complete carrier, under a calibrated sink bound.
  def ready(s: State): bool = valid(s) and s.sufficient and s.transportFits and seeds(s.exposed, s.applicable).size() > 0
  def outcome(s: State): str =
    if (not(s.current)) "source-gap"
    else if (not(s.receipts)) "receipt-gap"
    else if (not(s.conditions)) "condition-gap"
    else if (not(s.declared)) "declaration-gap"
    else if (not(s.evaluated)) "evaluation-gap"
    else if (not(s.sameWitness)) "conjunction-gap"
    else if (s.exposed.size() == 0) "anchor-gap"
    else if (seeds(s.exposed, Set(0, 1)).size() == 0) "association-gap"
    else if (seeds(s.exposed, s.applicable).size() == 0) "applicability-gap"
    else if (not(s.sufficient)) "presentation-gap"
    else if (not(s.transportFits)) "transport-gap" else "hit"
  action Query = {
    val restored = if (Mutation == "drop-query-on-replay" and q.queryOnly and not(q.hintVerified))
      Set() else q.exposed
    val scoped = seeds(restored, q.applicable)
    val result = if (valid(q)) family(scoped) else Set()
    // Unverified presentation hints cannot suppress evidence; history remains.
    val prior = if (q.hintVerified or Mutation == "reuse-unverified-delivery") q.prior else Set()
    val shown = if (Mutation == "dump-graph") Set(0, 1, 2, 3)
      else if (Mutation == "hide-counter") result.exclude(Set(1, 3))
      else if (q.sufficient and q.full and q.transportFits) result else Set()
    all {not(q.queried), q' = {...q, queried: true, scope: scoped, items: result, resolvedAnchors: restored,
      hit: if (Mutation == "drop-first-hit") false
        else if (Mutation == "invalid-declaration-hit") ready({...q, declared: true})
        else if (Mutation == "mix-witnesses") ready({...q, sameWitness: true})
        else if (Mutation == "index-only-hit") ready({...q, receipts: true})
        else if (Mutation == "invent-hit") true else ready(q),
      visible: shown,
      references: if (Mutation == "wrong-chain") Set(2) else if (valid(q)) scoped else Set(),
      expandable: if (q.sufficient and q.full and q.transportFits) Set() else result,
      complete: if (Mutation == "hide-truncation") true else valid(q) and q.sufficient and q.full and q.transportFits,
      acknowledged: (valid(q) and q.sufficient and q.full and q.transportFits)
        or Mutation == "ack-collapsed"
        or (Mutation == "ack-before-delivery" and valid(q) and q.sufficient and q.full),
      absent: Mutation == "gap-as-absent" and not(ready(q)),
      status: if (Mutation == "mask-gap") "hit" else outcome(q),
      discovered: if (Mutation == "invent-discovery") Set(2)
        else if (Mutation == "hide-discovery") Set()
        else if (valid(q) and q.exposed.size() == 0) associations.map(a => a.factor) else Set(),
      added: if (Mutation == "count-only-delta" and result.size() == prior.size())
        Set() else result.exclude(prior),
      removed: prior.intersect(family(scoped)).exclude(result), retained: result.intersect(prior),
      selectedAction: Mutation == "select-action", explorationOpen: Mutation != "close-scope"}}
  }
  action step = any {Prepare, Gap, Query}
  val FirstHit = not(q.queried and ready(q)) or q.hit
  val SoundHit = not(q.queried and q.hit) or ready(q)
  val Local = not(q.queried) or q.visible.subseteq(family(q.scope))
  val Family = not(q.queried and valid(q) and q.sufficient and q.full and q.transportFits) or q.visible == q.items
  val Traceable = not(q.queried) or
    q.references == (if (valid(q)) seeds(q.exposed, q.applicable) else Set())
  val HonestPresentation = not(q.queried) or
    (q.complete == (valid(q) and q.sufficient and q.full and q.transportFits) and
      q.expandable == (if (q.sufficient and q.full and q.transportFits) Set() else q.items))
  val Acknowledged = not(q.queried and q.acknowledged) or q.complete
  val DeliveryAcknowledged = not(q.queried and q.acknowledged) or q.transportFits
  val Gaps = not(q.queried) or (q.status == outcome(q) and not(q.absent))
  val ExactDelta = not(q.queried) or
    (q.added == q.items.exclude(if (q.hintVerified) q.prior else Set()) and
      q.removed == (if (q.hintVerified) q.prior else Set()).intersect(family(q.scope)).exclude(q.items) and
      q.retained == q.items.intersect(if (q.hintVerified) q.prior else Set()))
  val VerifiedReuse = not(q.queried and not(q.hintVerified)) or
    (q.retained == Set() and q.added == q.items)
  val QueryRetained = not(q.queried and q.queryOnly) or q.resolvedAnchors == q.exposed
  val Open = not(q.selectedAction) and q.explorationOpen
  val DiscoveryExact = not(q.queried) or q.discovered ==
    (if (valid(q) and q.exposed.size() == 0) associations.map(a => a.factor) else Set())
  val Safety = FirstHit and SoundHit and Local and Family and Traceable and
    HonestPresentation and Acknowledged and DeliveryAcknowledged and VerifiedReuse and QueryRetained and Gaps and ExactDelta and Open and DiscoveryExact
}
