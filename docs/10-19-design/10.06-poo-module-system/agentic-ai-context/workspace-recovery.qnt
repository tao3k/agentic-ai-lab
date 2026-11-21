// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module DurableRecoveryExtension {
  type Recovery = {
    owner: int,
    attempt: int,
    effect: int,
    policyRevision: int,
    cut: int,
    binding: bool,
    recordedOutcome: str,
    observationsAvailable: bool,
    interpretation: str,
    permission: bool,
    repeatSafe: bool,
    repeatSafeFor: int,
    policyAllows: bool,
    eligible: bool,
    receiptCut: int,
    capabilityAvailable: bool,
    capabilityCut: int,
    usedAtCut: bool,
    handoffLive: bool,
    spentCut: int,
    redispatched: bool,
    lastRefusal: str
  }

  var s: Recovery

  action init = s' = {
    owner: 0, attempt: 1, effect: 1, policyRevision: 1, cut: 0, binding: false, recordedOutcome: "unknown",
    observationsAvailable: false, interpretation: "unknown",
    permission: false, repeatSafe: false, repeatSafeFor: -1, policyAllows: false,
    eligible: false, receiptCut: -1, capabilityAvailable: false, capabilityCut: 0,
    usedAtCut: false, handoffLive: false, spentCut: -1, redispatched: false, lastRefusal: "none"
  }

  action takeover = all {
    s.owner < 2,
    s' = {
      ...s, cut: s.cut + 1, owner: s.owner + 1, binding: false, interpretation: "unknown",
      permission: false, repeatSafe: false, repeatSafeFor: -1, policyAllows: false,
      eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false
    }
  }

  action resolveBinding(matches: bool): bool = s' = {
    ...s, cut: s.cut + 1, binding: matches, interpretation: "unknown", policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false
  }

  // The deployed worker qualifies its joined observation in the named
  // workspace-result transaction. A file write alone only supplies a read.
  action observeOutcome(result: str): bool = all {
    result.in(Set("succeeded", "failed")),
    s.recordedOutcome == "unknown",
    s' = { ...s, cut: s.cut + 1, recordedOutcome: result, policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false }
  }

  action admitObservations = s' = {
    ...s, cut: s.cut + 1, observationsAvailable: true, interpretation: "unknown", policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false
  }

  action interpretOutcome(result: str): bool = all {
    s.binding,
    s.observationsAvailable,
    s.recordedOutcome == "unknown",
    result.in(Set("unknown", "succeeded", "failed")),
    s' = { ...s, cut: s.cut + 1, interpretation: result, policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false }
  }

  val effectiveOutcome =
    if (s.recordedOutcome == "unknown") s.interpretation else s.recordedOutcome

  action admitPermission(granted: bool): bool = s' = {
    ...s, cut: s.cut + 1, permission: granted, policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false
  }

  action admitRepeatSafety(safe: bool): bool = s' = {
    ...s, cut: s.cut + 1, repeatSafe: safe, repeatSafeFor: s.spentCut, policyAllows: false, eligible: false, capabilityAvailable: false, capabilityCut: 0, usedAtCut: false, handoffLive: false, redispatched: false
  }

  action proposeRetry(allowed: bool): bool = all {
    s.binding,
    effectiveOutcome != "succeeded",
    s' = { ...s, policyAllows: allowed, eligible: false, capabilityAvailable: false, capabilityCut: 0, handoffLive: false, redispatched: false }
  }

  val hasRetryBasis =
    s.binding and s.permission and s.repeatSafe and s.policyAllows
      and effectiveOutcome != "succeeded"

  action assessEligibility = s' = {
    ...s, eligible: hasRetryBasis and s.repeatSafeFor == s.spentCut, receiptCut: s.cut, capabilityAvailable: false, capabilityCut: 0, handoffLive: false, redispatched: false
  }

  // Abstracts a fresh host capability admitted for the current evidence cut.
  action admitCapability = all {
    s.eligible,
    s.receiptCut == s.cut,
    s.repeatSafeFor == s.spentCut,
    not(s.usedAtCut),
    s' = { ...s, capabilityAvailable: true, capabilityCut: s.cut }
  }

  // The current cut abstracts the host checking that its fresh scoped
  // observation still matches the committed receipt.
  action consumeCapability = all {
    s.eligible,
    hasRetryBasis,
    s.receiptCut == s.cut,
    s.capabilityAvailable,
    s.capabilityCut == s.cut,
    s.repeatSafeFor == s.spentCut,
    not(s.usedAtCut),
    s' = { ...s, capabilityAvailable: false, usedAtCut: true,
           handoffLive: true, spentCut: s.cut, redispatched: false }
  }

  // A takeover clears the live handoff while retaining its durable spend.
  // Starting the endpoint does not record an outcome.
  action finishHandoff(issuerConsumed: bool): bool = all {
    s.handoffLive,
    s.spentCut == s.cut,
    s.receiptCut == s.cut,
    hasRetryBasis,
    s' = { ...s, handoffLive: false, redispatched: issuerConsumed }
  }

  pure def refusalFor(digestMatches: bool, isCurrent: bool, succeeded: bool,
                      eligible: bool, spent: bool): str =
    if (not(digestMatches) or not(isCurrent)) "stale-or-mismatched-decision"
    else if (succeeded) "effect-already-succeeded"
    else if (not(eligible)) "recovery-ineligible"
    else if (spent) "decision-reuse"
    else "none"

  action refuseRetry(digestMatches: bool): bool = {
    val reason = refusalFor(digestMatches, s.receiptCut == s.cut,
      effectiveOutcome == "succeeded", s.eligible, s.usedAtCut)
    all {
      reason != "none",
      s' = { ...s, lastRefusal: reason }
    }
  }

  action step = any {
    all {
      s.cut < 8,
      any {
        takeover,
        resolveBinding(true), resolveBinding(false),
        observeOutcome("succeeded"), observeOutcome("failed"),
        admitObservations,
        interpretOutcome("unknown"), interpretOutcome("succeeded"), interpretOutcome("failed"),
        admitPermission(true), admitPermission(false),
        admitRepeatSafety(true), admitRepeatSafety(false)
      }
    },
    proposeRetry(true), proposeRetry(false),
    assessEligibility, admitCapability, consumeCapability,
    finishHandoff(true), finishHandoff(false),
    refuseRetry(true), refuseRetry(false)
  }

  val sameAttempt = s.attempt == 1 and s.effect == 1 and s.policyRevision == 1
  val capabilityCurrent = s.capabilityAvailable implies
    (s.capabilityCut == s.cut and s.repeatSafeFor == s.spentCut)
  val eligibilityHasBasis = s.eligible implies (hasRetryBasis and s.receiptCut == s.cut)
  val liveHandoffHasSpend = s.handoffLive implies (s.spentCut == s.cut and s.usedAtCut)
  val dispatchHasBasis = s.redispatched implies (hasRetryBasis and s.usedAtCut and not(s.capabilityAvailable))
  val successVeto = (effectiveOutcome == "succeeded") implies
    (not(s.eligible) and not(s.redispatched))
}

// Design-only finite abstraction of Temporal evidence revision and open inquiry.
// Admission is an explicit trusted boundary assumption, not source verification.
// The earlier module models dispatch; this module models knowledge and duties.
module RecoveryEvidenceInquiry {
  type Binding = { id: str, attempt: str, effect: str, write: str, record: str }
  type Assessment = { binding: Binding, basisCut: int, authorized: bool,
    lineageComplete: bool, dependsOnR1: bool, committedEffect: bool,
    outcomeContested: bool }
  type DispatchManifest = { cut: int, scope: str, slots: Set[str], authorized: bool }
  type DispatchRow = { slot: str, cut: int, scope: str, authorized: bool, sealed: bool, event: str }
  type ClaimBasis = { claim: str, digest: str, evidence: str, scope: str,
    cut: int, verified: bool, coverage: bool, count: int, supports: bool }
  type SummaryVersion = { version: int, parent: int, cut: int, reviewRevision: int,
    assertions: Set[str], basis: Set[ClaimBasis], dispatchManifests: Set[DispatchManifest], dispatchRows: Set[DispatchRow], withdrawn: Set[str], unresolved: Set[str], partial: bool }
  type SummaryReview = { revision: int, checked: Set[ClaimBasis],
    drafts: Set[SummaryVersion], published: Set[SummaryVersion], archive: Set[int],
    dispatchManifests: Set[DispatchManifest], dispatchRows: Set[DispatchRow] }
  type View = { cut: int, bytesSeen: bool, successUses: Set[str], withdrawnUses: Set[str],
    pendingUses: Set[str], affectedJudgments: Set[str], w1Lineage: str,
    contested: bool, receiptCorrected: bool, proposed: Set[str], findings: Set[str],
    correctionCut: int, admittedBasis: Set[Assessment], candidates: Set[Binding],
    priorCuts: Set[int], successHistory: Set[int], summary: SummaryReview }
  var v: View
  action init = v' = { cut: 0, bytesSeen: false, successUses: Set(), withdrawnUses: Set(),
    pendingUses: Set(), affectedJudgments: Set(), w1Lineage: "independent",
    contested: false, receiptCorrected: false, proposed: Set(), findings: Set(),
    correctionCut: -1, admittedBasis: Set(), candidates: Set(),
    priorCuts: Set(), successHistory: Set(),
    summary: { revision: 0, checked: Set(), drafts: Set(), published: Set(), archive: Set(), dispatchManifests: Set(), dispatchRows: Set() } }

  // Arrows run from a premise to its dependent. The scoped graph has
  // nine vertices, so nine rounds cover every simple reachable path.
  pure def impact(lineage: str): Set[str] = {
    val base = Set(("R1-attribution", "R1"), ("R1", "R1-copy"),
      ("attempt-crosswalk", "W1-attribution"), ("W1-attribution", "W1"),
      ("W1-record", "W1"), ("R1", "outcome-B"), ("R1-copy", "outcome-B"),
      ("W1", "outcome-B"), ("outcome-B", "summary-B"))
    val edges = if (lineage == "indirect")
      base.union(Set(("R1-attribution", "attempt-crosswalk"))) else base
    0.to(8).fold(Set("R1-attribution"), (seen, _) =>
      seen.union(edges.filter(e => seen.contains(e._1)).map(e => e._2)))
  }
  val judgmentKeys = Set("outcome-B", "summary-B")
  pure def hasSuccess(uses: Set[str], conflict: bool): bool =
    uses != Set() and not(conflict)
  pure def revised(old: View, uses: Set[str], conflict: bool): View = {
    ...old, cut: old.cut + 1, successUses: uses, withdrawnUses: Set(),
    pendingUses: Set(), affectedJudgments: Set(),
    contested: conflict, receiptCorrected: false, correctionCut: -1, admittedBasis: Set(),
    priorCuts: old.priorCuts.union(Set(old.cut)),
    successHistory: if (hasSuccess(old.successUses, old.contested))
      old.successHistory.union(Set(old.cut)) else old.successHistory
  }

  // Admission for the exact effect is a trusted boundary. These transitions
  // refer to the original versions, which cannot be reused after R2.
  action revise(uses: Set[str], conflict: bool, lineage: str): bool = all {
    v.cut < 3,
    not(v.receiptCorrected),
    v' = { ...revised(v, uses, conflict), w1Lineage: lineage }
  }
  action admitSuccess = any {
    revise(Set("R1"), false, "independent"),
    revise(Set("R1", "R1-copy"), false, "independent"),
    revise(Set("R1", "R1-copy", "W1"), false, "independent"),
    revise(Set("R1", "W1"), false, "indirect"),
    revise(Set("R1", "W1"), false, "unverified"),
    revise(Set("W1"), false, "independent")
  }

  action correctAttribution = {
    val reached = impact(v.w1Lineage)
    val pending = if (v.w1Lineage == "unverified") v.successUses.intersect(Set("W1")) else Set()
    all {
      v.cut < 3,
      succeeded,
      v.successUses.contains("R1"),
      v' = { ...revised(v, v.successUses.exclude(reached).exclude(pending), v.contested),
        receiptCorrected: true, correctionCut: v.cut + 1, withdrawnUses: v.successUses.intersect(reached),
        pendingUses: pending, affectedJudgments: reached.intersect(judgmentKeys),
        summary: { ...v.summary, archive: Set(1) } }
    }
  }
  action observeBytes = v' = { ...v, bytesSeen: true }
  val clues = Set("receipt-source", "other-writer", "file-history",
    "independent-effect-record", "compare-identities", "check-dependencies", "review-withdrawn-uses",
    "inspect-crosswalk", "validate-direct-binding")
  action propose(clue: str): bool = all {
    clue.in(clues),
    v' = { ...v, proposed: v.proposed.union(Set(clue)) }
  }
  // Findings enter candidate lineage; their presence never admits success.
  action findClue(clue: str): bool = all {
    clue.in(v.proposed),
    v' = { ...v, findings: v.findings.union(Set(clue)) }
  }
  // Bounded fixtures. IDs stand for immutable, content-bound versions.
  val direct = { id: "D1", attempt: "original-attempt", effect: "append-effect",
    write: "storage-write-42", record: "W1-record-digest" }
  val bindingCandidates = Set(direct,
    { ...direct, id: "other-attempt", attempt: "another-attempt" },
    { ...direct, id: "other-effect", effect: "another-effect" },
    { ...direct, id: "other-write", write: "storage-write-43" },
    { ...direct, id: "other-record", record: "another-record-digest" })
  action discoverBinding(binding: Binding): bool = all {
    v.receiptCorrected,
    binding.in(bindingCandidates),
    v' = { ...v, candidates: v.candidates.union(Set(binding)) }
  }

  pure def qualifies(cut: int, assessment: Assessment): bool = all {
    assessment.basisCut == cut,
    assessment.binding.attempt == "original-attempt",
    assessment.binding.effect == "append-effect",
    assessment.binding.write == "storage-write-42",
    assessment.binding.record == "W1-record-digest",
    assessment.authorized,
    assessment.lineageComplete,
    not(assessment.dependsOnR1),
    assessment.committedEffect
  }
  // Assessment fields represent facts supplied by the authorized Temporal
  // evaluator, separate from discovery. Only this action selects a new use.
  action readmitW1(assessment: Assessment): bool = all {
    v.cut < 4,
    v.receiptCorrected,
    v.admittedBasis == Set(),
    v.withdrawnUses.union(v.pendingUses).contains("W1"),
    assessment.binding.in(v.candidates),
    qualifies(v.cut, assessment),
    v' = { ...v, cut: v.cut + 1, admittedBasis: Set(assessment),
      successUses: v.successUses.union(Set("W1-v2")),
      contested: v.contested or assessment.outcomeContested,
      priorCuts: v.priorCuts.union(Set(v.cut)),
      summary: { ...v.summary, revision: 0, checked: Set(), drafts: Set() } }
  }
  pure def assessments(binding: Binding, cut: int): Set[Assessment] = {
    val accepted = { binding: binding, basisCut: cut, authorized: true,
      lineageComplete: true, dependsOnR1: false, committedEffect: true,
      outcomeContested: false }
    Set(accepted, { ...accepted, basisCut: cut - 1 },
      { ...accepted, authorized: false }, { ...accepted, lineageComplete: false },
      { ...accepted, dependsOnR1: true }, { ...accepted, committedEffect: false },
      { ...accepted, outcomeContested: true })
  }
  // The manifest is the claim inventory of the retained summary-B.
  val summaryManifest = Set("append-committed", "single-commit", "no-replay-dispatch")
  pure def claimBasis(claim: str, cut: int): ClaimBasis = {
    val evidence = if (claim == "append-committed") "W1-v2"
      else if (claim == "single-commit") "storage-commit-audit-v2" else "dispatch-audit-v2"
    val scope = if (claim == "append-committed") "original-attempt/append-effect"
      else "original-attempt/append-effect/recovery-window"
    val digest = if (claim == "append-committed") "append-committed-digest"
      else if (claim == "single-commit") "single-commit-digest"
      else if (claim == "no-replay-dispatch") "no-replay-dispatch-digest" else "one-replay-dispatch-digest"
    { claim: claim, digest: digest, evidence: evidence, scope: scope,
      cut: cut, verified: true, coverage: true,
      count: if (claim == "no-replay-dispatch") 0 else 1, supports: true }
  }
  pure def replayRefutation(cut: int): ClaimBasis =
    { ...claimBasis("no-replay-dispatch", cut), count: 1, coverage: false, supports: false }
  val summaryReviewKeys = summaryManifest.union(Set("one-replay-dispatch"))
  pure def validClaimBasis(b: ClaimBasis, cut: int): bool =
    b.claim.in(summaryReviewKeys) and
      (b == claimBasis(b.claim, cut) or b == replayRefutation(cut))
  pure def positiveClaims(bases: Set[ClaimBasis]): Set[str] =
    bases.filter(b => b.supports).map(b => b.claim)
  pure def refutedClaims(bases: Set[ClaimBasis]): Set[str] =
    bases.filter(b => not(b.supports)).map(b => b.claim)
  val summaryAvailable = succeeded and v.successUses.contains("W1-v2")
    and v.affectedJudgments.contains("summary-B")
  val dispatchScope = "original-attempt/append-effect/recovery-window"
  val requiredDispatchSlots = Set("A/early", "A/late", "B/early", "B/late")
  pure def expectedDispatchManifest(cut: int): DispatchManifest =
    { cut: cut, scope: dispatchScope, slots: requiredDispatchSlots, authorized: true }
  pure def qualifiedDispatchRow(row: DispatchRow, cut: int): bool =
    row.slot.in(requiredDispatchSlots) and row.cut == cut and row.scope == dispatchScope
      and row.authorized and row.sealed
  pure def completeDispatchCoverage(cut: int, manifests: Set[DispatchManifest],
      rows: Set[DispatchRow]): bool =
    manifests.contains(expectedDispatchManifest(cut))
      and rows.map(r => r.slot) == requiredDispatchSlots
      and rows.size() == requiredDispatchSlots.size()
      and rows.forall(r => qualifiedDispatchRow(r, cut))
  pure def replayIds(rows: Set[DispatchRow]): Set[str] =
    rows.filter(r => r.event != "").map(r => r.event)
  val coverageComplete = completeDispatchCoverage(v.cut, v.summary.dispatchManifests, v.summary.dispatchRows)
  val observedReplayIds = replayIds(v.summary.dispatchRows)
  val coverageReview = observedReplayIds != Set() and not(coverageComplete)

  action admitDispatchManifest(manifest: DispatchManifest): bool = all {
    summaryAvailable,
    manifest == expectedDispatchManifest(v.cut),
    not(manifest.in(v.summary.dispatchManifests)),
    v' = { ...v, summary: { ...v.summary,
      dispatchManifests: v.summary.dispatchManifests.union(Set(manifest)) } }
  }
  action admitDispatchRow(row: DispatchRow): bool = all {
    summaryAvailable,
    qualifiedDispatchRow(row, v.cut),
    not(v.summary.dispatchRows.exists(r => r.slot == row.slot)),
    v' = { ...v, summary: { ...v.summary,
      dispatchRows: v.summary.dispatchRows.union(Set(row)) } }
  }
  pure def dispatchBasesAllowed(basis: ClaimBasis, cut: int,
      manifests: Set[DispatchManifest], rows: Set[DispatchRow]): bool =
    if (basis.claim == "no-replay-dispatch" and not(basis.supports))
      rows.exists(r => qualifiedDispatchRow(r, cut) and r.event != "")
    else if (basis.claim == "no-replay-dispatch" or basis.claim == "one-replay-dispatch")
      completeDispatchCoverage(cut, manifests, rows) and replayIds(rows).size() == basis.count
    else true
  val checkedClaims = v.summary.checked.map(b => b.claim)
  val exactReplayReview = observedReplayIds != Set() and not(checkedClaims.contains("one-replay-dispatch"))
  val openSummaryClaims = summaryManifest.exclude(checkedClaims)
  // An authorized evaluator verifies the exact use and semantic digest.
  // For audit claims, coverage includes the entire declared recovery window.
  action assessSummaryClaim(basis: ClaimBasis): bool = all {
    summaryAvailable,
    validClaimBasis(basis, v.cut),
    dispatchBasesAllowed(basis, v.cut, v.summary.dispatchManifests, v.summary.dispatchRows),
    not(basis.claim == "one-replay-dispatch" and
      positiveClaims(v.summary.checked).contains("no-replay-dispatch")),
    not(basis.claim == "no-replay-dispatch" and basis.supports and
      checkedClaims.contains("one-replay-dispatch")),
    not(basis.claim.in(checkedClaims)),
    v' = { ...v, summary: { ...v.summary, revision: v.summary.revision + 1,
      checked: v.summary.checked.union(Set(basis)) } }
  }
  val summaryDraft = { version: v.summary.archive.size() + 1,
    parent: v.summary.archive.size(), cut: v.cut, reviewRevision: v.summary.revision,
    assertions: positiveClaims(v.summary.checked), basis: v.summary.checked,
    dispatchManifests: v.summary.dispatchManifests, dispatchRows: v.summary.dispatchRows,
    withdrawn: refutedClaims(v.summary.checked), unresolved: openSummaryClaims,
    partial: openSummaryClaims != Set() }
  action proposeSummary(draft: SummaryVersion): bool = all {
    summaryAvailable,
    v' = { ...v, summary: { ...v.summary, drafts: v.summary.drafts.union(Set(draft)) } }
  }
  action admitSummary(draft: SummaryVersion): bool = all {
    summaryAvailable,
    draft.in(v.summary.drafts),
    draft == summaryDraft,
    draft.assertions.contains("append-committed"),
    draft.assertions.contains("one-replay-dispatch") implies
      draft.withdrawn.contains("no-replay-dispatch"),
    not(v.summary.published.exists(p => p.reviewRevision == draft.reviewRevision)),
    v' = { ...v, summary: { ...v.summary, published: v.summary.published.union(Set(draft)),
      archive: v.summary.archive.union(Set(draft.version)) } }
  }
  val summaryPublicationDuty = summaryAvailable and
    not(v.summary.published.exists(p => p.reviewRevision == v.summary.revision))
  action wait = v' = v
  action step = any {
    observeBytes,
    admitSuccess, correctAttribution, revise(Set(), false, "independent"), revise(Set("R1"), true, "independent"),
    { nondet clue = clues.oneOf(); propose(clue) },
    { nondet clue = clues.oneOf(); findClue(clue) },
    { nondet binding = bindingCandidates.oneOf(); discoverBinding(binding) },
    { nondet binding = bindingCandidates.oneOf()
      nondet assessment = assessments(binding, v.cut).oneOf()
      readmitW1(assessment) },
    { val exact = expectedDispatchManifest(v.cut)
      nondet manifest = Set(exact, { ...exact, authorized: false },
        { ...exact, slots: Set("A/early", "A/late") }).oneOf()
      admitDispatchManifest(manifest) },
    { nondet slot = requiredDispatchSlots.oneOf()
      nondet event = Set("", "replay-42", "replay-43").oneOf()
      val exact = { slot: slot, cut: v.cut, scope: dispatchScope, authorized: true,
        sealed: true, event: event }
      nondet row = Set(exact, { ...exact, sealed: false },
        { ...exact, cut: v.cut - 1 }).oneOf()
      admitDispatchRow(row) },
    { nondet claim = summaryReviewKeys.oneOf()
      val exact = claimBasis(claim, v.cut)
      nondet basis = Set(exact, replayRefutation(v.cut), { ...exact, evidence: "W1-v2" },
        { ...exact, cut: v.cut - 1 }, { ...exact, coverage: false }).oneOf()
      assessSummaryClaim(basis) },
    { nondet draft = Set(summaryDraft,
        { ...summaryDraft, assertions: summaryManifest, unresolved: Set(), partial: false },
        { ...summaryDraft, cut: v.cut - 1 }).oneOf()
      proposeSummary(draft) },
    { nondet draft = v.summary.drafts.oneOf(); admitSummary(draft) },
    wait
  }
  val succeeded = hasSuccess(v.successUses, v.contested)
  val outcome = if (succeeded) "succeeded" else "unknown"
  // Stable original Attempt/question key; repeated observations add no copies.
  val duties = if (succeeded) Set() else Set("original-attempt/outcome")
  val attributionDuties = if (v.bytesSeen and not(succeeded))
    Set("original-attempt/attribution") else Set()
  // Suggested questions at the current cut. Other investigations and waiting
  // remain available in step, regardless of the current outcome.
  val affectedUseReview = v.withdrawnUses.union(v.pendingUses)
  val judgmentReview = if (v.successUses.contains("W1-v2") and succeeded)
    v.affectedJudgments.exclude(Set("outcome-B"))
      .exclude(if (openSummaryClaims == Set() and not(summaryPublicationDuty))
        Set("summary-B") else Set())
    else v.affectedJudgments
  val bindingReview = if (affectedUseReview.contains("W1") and not(v.successUses.contains("W1-v2")))
    Set("original-attempt/W1-attribution") else Set()
  val frontier = if (v.successUses.contains("W1-v2"))
    Set("review-withdrawn-uses")
    else if (succeeded and v.receiptCorrected) Set("review-withdrawn-uses")
    else if (succeeded) Set("check-dependencies")
    else if (bindingReview != Set()) Set("inspect-crosswalk", "validate-direct-binding", "independent-effect-record")
    else if (v.receiptCorrected) Set("compare-identities", "independent-effect-record")
    else Set("receipt-source", "other-writer")
  val correctedSupportIsHistorical = v.receiptCorrected implies
    (v.withdrawnUses.contains("R1") and v.successUses.intersect(impact(v.w1Lineage)) == Set()
      and v.successUses.intersect(v.pendingUses) == Set()
      and v.affectedJudgments.contains("outcome-B") and v.affectedJudgments.contains("summary-B")
      and v.successHistory.contains(v.correctionCut - 1))
  val survivingSupportDeterminesDuty = v.receiptCorrected implies
    (duties.contains("original-attempt/outcome") ==
      (v.contested or not(v.successUses.contains("W1") or v.successUses.contains("W1-v2"))))
  val newVersionRetainsOldBasis = v.successUses.contains("W1-v2") implies
    (v.admittedBasis.size() == 1 and v.admittedBasis.forall(a =>
      qualifies(v.cut - 1, a) and v.priorCuts.contains(a.basisCut))
      and not(v.successUses.contains("W1"))
      and v.withdrawnUses.union(v.pendingUses).contains("W1")
      and bindingReview == Set() and v.affectedJudgments.contains("summary-B"))
  val noCompletionFromAppearance = (v.successUses == Set()) implies outcome == "unknown"
  val contestedStaysOpen = v.contested implies duties.contains("original-attempt/outcome")
  val unknownRetainsResponsibility = (outcome == "unknown") == duties.contains("original-attempt/outcome")
  val earlierViewsRetained = v.priorCuts == 0.to(v.cut - 1)
  val successHistoryRetained = v.successHistory.subseteq(v.priorCuts)
  val admittedSummaryCoverage = v.summary.published.forall(p =>
    p.version.in(v.summary.archive) and p.parent.in(v.summary.archive)
      and p.assertions == positiveClaims(p.basis)
      and p.withdrawn == refutedClaims(p.basis)
      and p.assertions.intersect(p.withdrawn) == Set()
      and (p.assertions.contains("one-replay-dispatch") implies
        p.withdrawn.contains("no-replay-dispatch"))
      and p.unresolved == summaryManifest.exclude(p.assertions.union(p.withdrawn))
      and p.partial == (p.unresolved != Set())
      and p.basis.forall(b => validClaimBasis(b, p.cut)
        and dispatchBasesAllowed(b, p.cut, p.dispatchManifests, p.dispatchRows)))
  val inquiryInvariant = noCompletionFromAppearance and contestedStaysOpen and
    unknownRetainsResponsibility and earlierViewsRetained and successHistoryRetained
    and correctedSupportIsHistorical and survivingSupportDeterminesDuty
    and newVersionRetainsOldBasis and admittedSummaryCoverage
}

// Independent dispatch-evidence cut over the same Attempt and effect.
module DispatchSealRevision {
  import RecoveryEvidenceInquiry as Coverage

  type DispatchIdentity = { id: str, slot: str, attempt: str, effect: str,
    time: int, cut: int, authorized: bool, replay: bool }
  type ExactTwoBasis = { cut: int, manifests: Set[Coverage::DispatchManifest],
    rows: Set[Coverage::DispatchRow], first: DispatchIdentity, second: DispatchIdentity }
  type AliasCorrection = { target: ExactTwoBasis, scope: str, authorized: bool }
  type LateDiscovery = { prior: DispatchIdentity, discovered: DispatchIdentity }
  type CopyObservation = { record: str, canonical: DispatchIdentity, attested: bool }
  type Snapshot = { cut: int, claim: str, manifests: Set[Coverage::DispatchManifest],
    rows: Set[Coverage::DispatchRow], identityBasis: Set[ExactTwoBasis], correction: Set[AliasCorrection], late: Set[LateDiscovery] }
  type State = { cut: int, manifests: Set[Coverage::DispatchManifest],
    rows: Set[Coverage::DispatchRow], exactAssessed: bool, exactTwoBasis: Set[ExactTwoBasis], selected: Set[Snapshot],
    history: Set[Snapshot], correction: Set[AliasCorrection], late: Set[LateDiscovery],
    copies: Set[CopyObservation] }
  var d: State
  pure def row(slot: str, cut: int, event: str): Coverage::DispatchRow =
    { slot: slot, cut: cut, scope: Coverage::dispatchScope, authorized: true, sealed: true, event: event }
  val original = { cut: 0, claim: "exact-one", manifests: Set(Coverage::expectedDispatchManifest(0)),
    rows: Set(row("A/early", 0, "replay-42"), row("A/late", 0, ""),
      row("B/early", 0, ""), row("B/late", 0, "")), identityBasis: Set(), correction: Set(), late: Set() }
  action init = d' = { cut: 0, manifests: original.manifests, rows: original.rows,
    exactAssessed: true, exactTwoBasis: Set(), selected: Set(original), history: Set(original), correction: Set(), late: Set(), copies: Set() }

  // A qualified correction revokes the B/late seal. Other ranges enter the
  // new cut through explicit requalification, never by relabeling old rows.
  action correctSeal = all {
    d.cut == 0,
    d' = { ...d, cut: 1, manifests: Set(), rows: Set(), exactAssessed: false, exactTwoBasis: Set(), selected: Set() }
  }
  action admitManifest = all {
    d.cut > 0, d.manifests == Set(),
    d' = { ...d, manifests: Set(Coverage::expectedDispatchManifest(d.cut)) }
  }
  action qualifyRange(r: Coverage::DispatchRow): bool = all {
    d.cut > 0,
    Coverage::qualifiedDispatchRow(r, d.cut),
    not(d.rows.exists(prior => prior.slot == r.slot)),
    d' = { ...d, rows: d.rows.union(Set(r)) }
  }
  val complete = Coverage::completeDispatchCoverage(d.cut, d.manifests, d.rows)
  val replayWitness = Coverage::replayIds(d.rows) != Set()
  val countReviewOpen = d.cut > 0 and not(d.exactAssessed) and d.exactTwoBasis == Set()
  val coverageReviewOpen = d.cut > 0 and not(complete)
  val correctedExactOne = d.correction.exists(c =>
    c.target.cut + 1 == d.cut and c.authorized and c.scope == Coverage::dispatchScope
      and complete and Coverage::replayIds(d.rows) == Set(c.target.first.id)
      and d.rows.exists(r => r.slot == c.target.first.slot and r.event == c.target.first.id)
      and d.rows.exists(r => r.slot == c.target.second.slot and r.event == ""))
  val exactOneBasis = d.late == Set() and complete and Coverage::replayIds(d.rows).size() == 1
    and (d.cut < 2 or correctedExactOne)
  action assessExact = all {
    d.cut > 0, exactOneBasis, not(d.exactAssessed),
    d' = { ...d, exactAssessed: true }
  }
  // Times are symbolic coordinates within the scoped half-open window [10, 20).
  pure def identity(id: str, slot: str, time: int, cut: int): DispatchIdentity =
    { id: id, slot: slot, attempt: "original-attempt", effect: "append-effect",
      time: time, cut: cut, authorized: true, replay: true }
  pure def scopedReplay(x: DispatchIdentity, cut: int): bool =
    x.cut == cut and x.authorized and x.replay and x.id != ""
      and x.attempt == "original-attempt" and x.effect == "append-effect"
      and 10 <= x.time and x.time < 20
  pure def identityQualified(x: DispatchIdentity, cut: int, rows: Set[Coverage::DispatchRow]): bool =
    scopedReplay(x, cut)
      and rows.exists(r => Coverage::qualifiedDispatchRow(r, cut) and r.slot == x.slot and r.event == x.id)
  // Observation provenance can grow without changing the count basis.
  action observeKnownCopy(copy: CopyObservation): bool = all {
    copy.attested, copy.record != "", identityQualified(copy.canonical, d.cut, d.rows),
    d.copies.forall(old => old.record != copy.record or old == copy),
    d' = { ...d, copies: d.copies.union(Set(copy)) }
  }
  pure def sameDispatch(current: DispatchIdentity, earlier: DispatchIdentity): bool =
    current.id == earlier.id and current.slot == earlier.slot and current.time == earlier.time
  val lowerBoundTwo = d.late.exists(l => l.prior.cut + 1 == d.cut
    and scopedReplay(l.prior, l.prior.cut) and scopedReplay(l.discovered, l.prior.cut)
    and l.prior.id != l.discovered.id)
  pure def carriesDiscovery(b: ExactTwoBasis, late: Set[LateDiscovery], correction: Set[AliasCorrection]): bool =
    late.forall(l => l.prior.cut + 1 == b.cut
      and sameDispatch(b.first, l.prior) and sameDispatch(b.second, l.discovered)
      and correction.forall(c => b.rows.exists(r => r.slot == c.target.second.slot and r.event == "")))
  pure def validExactTwo(b: ExactTwoBasis): bool =
    Coverage::completeDispatchCoverage(b.cut, b.manifests, b.rows)
      and identityQualified(b.first, b.cut, b.rows)
      and identityQualified(b.second, b.cut, b.rows)
      and b.first.id != b.second.id
      and Coverage::replayIds(b.rows) == Set(b.first.id, b.second.id)
  action assessExactTwo(first: DispatchIdentity, second: DispatchIdentity): bool = {
    val basis = { cut: d.cut, manifests: d.manifests, rows: d.rows, first: first, second: second }
    all {
      d.cut > 0, not(d.exactAssessed), d.exactTwoBasis == Set(), validExactTwo(basis),
      (d.correction == Set() or lowerBoundTwo), carriesDiscovery(basis, d.late, d.correction),
      d' = { ...d, exactTwoBasis: Set(basis) }
    }
  }
  val exactTwoSelectable = d.exactTwoBasis.exists(b =>
    b.cut == d.cut and b.manifests == d.manifests and b.rows == d.rows and validExactTwo(b)
      and carriesDiscovery(b, d.late, d.correction))
  // The admitted attestation says the second observation forwards the first
  // dispatch. The selected basis identifies exactly which bindings it corrects.
  action correctAlias(c: AliasCorrection): bool = all {
    d.cut == 1, c.authorized, c.scope == Coverage::dispatchScope, exactTwoSelectable,
    d.selected.exists(s => s.cut == d.cut and s.claim == "exact-two"
      and s.identityBasis == Set(c.target) and s.identityBasis == d.exactTwoBasis),
    d' = { ...d, cut: 2, manifests: Set(), rows: Set(), exactAssessed: false,
      exactTwoBasis: Set(), selected: Set(), correction: Set(c) }
  }
  // A newly admitted observation may contradict a sealed inventory before
  // any replacement seal is ready. Its authority attests the occurrence time.
  action admitLateDiscovery(l: LateDiscovery): bool = all {
    d.selected.exists(s => s.claim == "exact-one" and s.cut == d.cut
      and s.manifests == d.manifests and s.rows == d.rows),
    d.correction != Set(), d.exactAssessed, exactOneBasis,
    identityQualified(l.prior, d.cut, d.rows), scopedReplay(l.discovered, d.cut),
    l.prior.id != l.discovered.id,
    d.rows.exists(r => r.slot == l.discovered.slot and r.event == ""),
    d' = { ...d, cut: d.cut + 1, manifests: Set(), rows: Set(), exactAssessed: false,
      exactTwoBasis: Set(), selected: Set(), late: Set(l) }
  }
  action publishRevision(claim: str): bool = {
    val snapshot = { cut: d.cut, claim: claim, manifests: d.manifests, rows: d.rows,
      identityBasis: if (claim == "exact-two") d.exactTwoBasis else Set(), correction: d.correction, late: d.late }
    all {
      d.cut > 0,
      if (claim == "exact-one") d.exactAssessed and exactOneBasis
      else if (claim == "exact-two") exactTwoSelectable
      else if (claim == "at-least-two") lowerBoundTwo and countReviewOpen
      else claim == "at-least-one" and replayWitness and not(lowerBoundTwo) and not(d.exactAssessed) and d.exactTwoBasis == Set(),
      not(d.selected.contains(snapshot)),
      d' = { ...d, selected: Set(snapshot), history: d.history.union(Set(snapshot)) }
    }
  }
  action wait = d' = d
  action step = any {
    correctSeal, admitManifest,
    observeKnownCopy({ record: "repeat-observation", canonical: identity("replay-42", "A/early", 12, d.cut), attested: true }),
    qualifyRange(row("A/early", d.cut, "replay-42")),
    qualifyRange(row("A/late", d.cut, "")),
    qualifyRange(row("B/early", d.cut, "")),
    { all { lowerBoundTwo, qualifyRange(row("B/early", d.cut, "replay-44")) } },
    { val prior = identity("replay-42", "A/early", 12, d.cut)
      val late = identity("replay-44", "B/early", 16, d.cut)
      nondet found = Set(late, { ...late, id: prior.id },
        { ...late, attempt: "another-attempt" }, { ...late, time: 20 }).oneOf()
      admitLateDiscovery({ prior: prior, discovered: found }) },
    qualifyRange(row("B/late", d.cut, "")),
    qualifyRange(row("B/late", d.cut, "replay-43")),
    { nondet target = d.exactTwoBasis.oneOf()
      correctAlias({ target: target, scope: Coverage::dispatchScope, authorized: true }) },
    { val first = identity("replay-42", "A/early", 12, d.cut)
      val exact = identity("replay-43", "B/late", 18, d.cut)
      nondet second = Set(exact, identity("replay-44", "B/early", 16, d.cut), { ...exact, id: first.id },
        { ...exact, attempt: "another-attempt" }, { ...exact, time: 20 },
        { ...exact, cut: d.cut - 1 }).oneOf()
      assessExactTwo(first, second) },
    assessExact, publishRevision("at-least-one"), publishRevision("at-least-two"), publishRevision("exact-one"),
    publishRevision("exact-two"), wait
  }
  val originalRetained = d.history.contains(original)
  val selectedExactHasCurrentProof = d.selected.forall(s => s.claim == "exact-one" implies
    (s.cut == d.cut and d.exactAssessed and exactOneBasis and s.correction == d.correction and d.late == Set()))
  val selectedTwoHasCurrentProof = d.selected.forall(s => s.claim == "exact-two" implies
    (s.cut == d.cut and s.identityBasis.size() == 1 and
      s.identityBasis.forall(b => b.cut == s.cut and b.rows == s.rows
        and b.manifests == s.manifests and validExactTwo(b)
        and carriesDiscovery(b, s.late, s.correction))))
  val correctedCountNeedsFreshBasis = (d.cut == 2 and d.late == Set() and not(correctedExactOne)) implies
    (countReviewOpen and d.selected.forall(s => s.claim != "exact-one"))
  val correctedHistoryRetainsV4 = d.correction.forall(c =>
    d.history.exists(s => s.claim == "exact-two" and s.cut == c.target.cut
      and s.identityBasis == Set(c.target)))
  val discoveryRetainsV5 = d.late.forall(l =>
    d.history.exists(s => s.claim == "exact-one" and s.cut == l.prior.cut))
  val noExactClaimFromLowerBoundAlone = (lowerBoundTwo and not(complete)) implies
    (countReviewOpen and d.selected.forall(s => s.claim != "exact-two" and s.claim != "exact-one"))
}
