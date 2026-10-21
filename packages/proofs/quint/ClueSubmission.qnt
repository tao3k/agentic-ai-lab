// Host journal refinement: two abstract clue IDs, two source generations.
// These are finite exploration bounds, not a limit on Agent input or CPU use.
module ClueSubmission {
  const Fault: str
  type Clue = {id: int, source: int}
  type Pending = {id: int, source: int, prefix: int}
  type State = {
    source: int, generation: int, rows: Set[Clue], pending: Set[Pending],
    view: Set[Clue], viewSource: int, viewPrefix: int, viewCurrent: bool,
    accepted: bool, expected: int, before: int, supported: Set[Clue]
  }
  var q: State
  action init = q' = {
    source: 0, generation: 0, rows: Set(), pending: Set(),
    view: Set(), viewSource: 0, viewPrefix: 0, viewCurrent: false,
    accepted: false, expected: 0, before: 0, supported: Set()
  }
  action Begin = {
    nondet id = Set(0, 1).oneOf()
    q' = {...q, pending: q.pending.union(Set({id: id, source: q.source, prefix: q.generation}))}
  }
  action Commit = all {
    q.pending.size() > 0, q.generation < 2,
    {
      nondet p = q.pending.oneOf()
      val fresh = (p.prefix == q.generation or Fault == "stale-cas") and
        p.source == q.source and not(q.rows.exists(r => r.id == p.id))
      q' = if (fresh) {
        ...q, rows: q.rows.union(Set({id: p.id, source: p.source})),
        generation: q.generation + 1, pending: q.pending.exclude(Set(p)),
        accepted: true, expected: p.prefix, before: q.generation, viewCurrent: false
      } else {...q, pending: q.pending.exclude(Set(p)), accepted: false}
    }
  }
  action ReplaceSource = all {q.source == 0,
    q' = {...q, source: 1, viewCurrent: false}}
  action Read = q' = {
    ...q, view: q.rows.filter(r => r.source == q.source),
    viewSource: q.source, viewPrefix: q.generation, viewCurrent: true,
    supported: if (Fault == "promote-hypothesis") q.rows else Set()
  }
  action Restart = q' = {
    ...q, pending: Set(), viewCurrent: false,
    rows: if (Fault == "drop-history") Set() else q.rows
  }
  action step = any {Begin, Commit, ReplaceSource, Read, Restart}
  val Durable = q.rows.size() == q.generation
  val CompareAndSwap = not(q.accepted) or q.expected == q.before
  val CurrentView = not(q.viewCurrent) or
    (q.viewSource == q.source and q.viewPrefix == q.generation and
      q.view == q.rows.filter(r => r.source == q.source))
  val HypothesisSeparation = q.supported == Set()
  val Safe = Durable and CompareAndSwap and CurrentView and HypothesisSeparation
}
