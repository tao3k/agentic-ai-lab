// Units are full families or full derived-relation results. An evidence family
// includes both witness polarities; derived results never mint observations.
// Finite instance, not a production scope or capacity restriction.
module ProgressiveEvidenceRead {
  const Mutation: str
  val scopes = Set(Set(), Set(0), Set(1), Set(0, 1))
  type State = {source: int, bound: int, scope: Set[int], lastScope: Set[int],
    seen: Set[int], before: Set[int], visible: Set[int], pending: Set[int],
    removed: Set[int], summarized: Set[int], sourceMatched: bool, read: bool, open: bool}
  var q: State
  action init = q' = {source: 0, bound: 0, scope: Set(), lastScope: Set(),
    seen: Set(), before: Set(), visible: Set(), pending: Set(), removed: Set(),
    summarized: Set(), sourceMatched: true, read: false, open: true}
  action Select = {
    nondet scope = scopes.oneOf()
    q' = {...q, scope: scope, read: false}
  }
  action SourceChanges = q' = {...q, source: 1 - q.source, read: false}
  action Read = {
    val same = q.source == q.bound
    val before = if (same or Mutation == "reuse-stale") q.seen else Set()
    val available = if (Mutation == "replay-seen") q.scope else q.scope.exclude(before)
    nondet shown = scopes.filter(s => s.subseteq(available)).oneOf()
    val after = if (Mutation == "ack-hidden") before.union(q.scope)
      else if (Mutation == "forget-on-rescope" and q.scope != q.lastScope) shown
      else before.union(shown)
    q' = {...q, bound: q.source, lastScope: q.scope, seen: after,
      before: before, visible: shown, pending: q.scope.exclude(after),
      summarized: q.scope.exclude(before.union(shown)),
      removed: if (Mutation == "scope-is-removal") before.exclude(q.scope) else Set(),
      sourceMatched: same, read: true, open: Mutation != "close-exploration"}
  }
  action step = any {Select, SourceChanges, Read}
  val NoReplay = not(q.read) or q.visible.intersect(q.before) == Set()
  val NoHiddenAcknowledgement = not(q.read) or q.seen.exclude(q.before) == q.visible
  val PreserveSeen = not(q.read) or q.before.subseteq(q.seen)
  val SourceBound = not(q.read and not(q.sourceMatched)) or q.before == Set()
  val ScopeIsNotRemoval = not(q.read) or q.removed == Set()
  val Progress = not(q.read and q.visible != Set()) or q.seen.size() > q.before.size()
  val HonestPending = not(q.read) or q.pending == q.scope.exclude(q.seen)
  // A content-bound group reference is presentation, never a read receipt.
  val SummaryPreservesPending = not(q.read) or q.summarized.subseteq(q.pending)
  val Open = q.open
  val Safety = NoReplay and NoHiddenAcknowledgement and PreserveSeen and SourceBound
    and ScopeIsNotRemoval and Progress and HonestPending and SummaryPreservesPending and Open
}
