// Finite query/state abstraction, not a host resource or exploration limit.
module ClueQueryResume {
  const Mutation: str
  type State = {phase: int, query: int, saved: int, caller: int,
    facts: Set[int], original: Set[int], visible: Set[int],
    active: bool, authority: bool, history: Set[int],
    contract: int, savedContract: int, readSeen: Set[int], originalSeen: Set[int],
    changed: Set[int], witnesses: Set[int], summaryStored: bool, summaryCurrent: bool}
  var q: State
  // A finite source-graph abstraction, not a runtime radius or search quota.
  // 0 -> 1 -> 2 represents config -> definition -> interpretation; 3 is disjoint.
  pure val sourceNodes = Set(0, 1, 2, 3)
  pure val sourceEdges = Set((0, 1), (1, 2))
  pure def sourceClosure(seeds: Set[int]): Set[int] =
    sourceNodes.fold(seeds, (seen, _node) =>
      seen.union(sourceEdges.filter(edge => seen.contains(edge._1)).map(edge => edge._2)))
  pure def summaryValid(changed: Set[int], witnesses: Set[int]): bool =
    not(sourceClosure(changed).contains(2)) and
    not(sourceClosure(sourceNodes.exclude(witnesses)).contains(2))
  pure def answers(query: int, facts: Set[int]): Set[int] =
    facts.filter(i => if (query == 0) Set(0, 1, 4).contains(i)
      else if (query == 1) Set(2, 3).contains(i) else false)
  action init = q' = {phase: 0, query: -1, saved: -1, caller: -1,
    facts: Set(0, 1, 2, 3), original: Set(), visible: Set(),
    active: false, authority: false, history: Set(0, 1),
    contract: 0, savedContract: 0, readSeen: Set(), originalSeen: Set(),
    changed: Set(), witnesses: sourceNodes, summaryStored: true, summaryCurrent: false}
  action Declare = {
    nondet query = Set(0, 1).oneOf()
    all {q.phase == 0,
      q' = {...q, phase: 1, query: query, saved: query,
        original: answers(query, q.facts), visible: answers(query, q.facts), active: true,
        readSeen: answers(query, q.facts), originalSeen: answers(query, q.facts),
        summaryCurrent: summaryValid(q.changed, q.witnesses)}}
  }
  action Interrupt = all {q.phase == 1,
    q' = {...q, phase: 2, query: -1, active: false, visible: Set(),
      summaryCurrent: false,
      summaryStored: q.summaryStored and Mutation != "erase-understanding"}}
  action ChangeSource = {
    nondet node = sourceNodes.oneOf()
    all {q.phase == 2, not(q.changed.contains(node)),
      q' = {...q, changed: q.changed.union(Set(node))}}
  }
  action LoseSourceWitness = {
    nondet node = sourceNodes.oneOf()
    all {q.phase == 2, q.witnesses.contains(node),
      q' = {...q, witnesses: q.witnesses.exclude(Set(node))}}
  }
  action ChangeFacts = all {q.phase == 2, not(q.facts.contains(4)),
    q' = {...q, facts: q.facts.union(Set(4))}}
  action WithdrawFact = all {q.phase == 2, q.facts.contains(0),
    q' = {...q, facts: q.facts.exclude(Set(0))}}
  action ChangeContract = all {q.phase == 2, q.contract == 0,
    q' = {...q, contract: 1}}
  action LoseDeclaration = all {q.phase == 2, q.saved >= 0,
    q' = {...q, saved: -1}}
  action Resume = all {q.phase == 2,
    val usable = q.saved >= 0 or Mutation == "guess-missing"
    val query = if (Mutation == "drop-query") 2 else if (q.saved >= 0) q.saved else 0
    q' = {...q, phase: 3, query: if (usable) query else -1, active: usable,
      visible: if (not(usable)) Set() else if (Mutation == "freeze-results") q.original
        else answers(query, q.facts),
      authority: Mutation == "authorize-resume",
      summaryCurrent: usable and q.summaryStored and
        (if (Mutation == "ignore-transitive-change") not(q.changed.contains(2))
          else not(sourceClosure(q.changed).contains(2))) and
        (Mutation == "ignore-scope-witness" or
          not(sourceClosure(sourceNodes.exclude(q.witnesses)).contains(2))),
      readSeen: if (Mutation == "replay-all") Set()
        else if (q.contract != q.savedContract and Mutation != "reuse-changed-contract") Set()
        else if (Mutation == "keep-removed-read") q.originalSeen
        else q.originalSeen.intersect(q.facts),
      history: if (Mutation == "erase-history") Set() else q.history}}
  action Override = {
    nondet caller = Set(0, 1, 2, 3).oneOf()
    all {q.phase == 3,
      val query = if (Mutation == "pin-caller") q.saved else caller
      q' = {...q, phase: 4, caller: caller, query: query, active: true,
        visible: answers(query, q.facts),
        summaryCurrent: q.summaryStored and summaryValid(q.changed, q.witnesses)}}
  }
  action step = any {Declare, Interrupt, ChangeFacts, WithdrawFact, ChangeContract,
    LoseDeclaration, ChangeSource, LoseSourceWitness, Resume, Override}
  val Restored = not(q.phase == 3 and q.saved >= 0) or q.query == q.saved
  val CurrentFacts = not(q.active) or q.visible == answers(q.query, q.facts)
  val MissingIsUnknown = not(q.phase == 3 and q.saved < 0) or not(q.active)
  val CallerOwnsScope = q.phase != 4 or q.query == q.caller
  val NoAuthority = not(q.authority)
  val History = q.history == Set(0, 1)
  val ExactReads = q.phase < 3 or q.readSeen ==
    (if (q.contract == q.savedContract) q.originalSeen.intersect(q.facts) else Set())
  val SummaryCurrentOnly = not(q.active) or
    q.summaryCurrent == (q.summaryStored and summaryValid(q.changed, q.witnesses))
  val UnderstandingSurvivesCompaction = q.summaryStored
  val Safety = Restored and CurrentFacts and MissingIsUnknown and CallerOwnsScope
    and NoAuthority and History and ExactReads and SummaryCurrentOnly and UnderstandingSurvivesCompaction
}
