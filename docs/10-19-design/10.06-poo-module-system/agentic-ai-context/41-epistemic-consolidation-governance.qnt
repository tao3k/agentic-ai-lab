// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 41 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 41-epistemic-consolidation-governance.sysml,
// unbounded list/budget induction and catalog frame laws live in 41-*.lean;
// this module explores nondeterministic races across two Sessions:
// 1. Asynchronous outcome arrivals vs consolidation proposals and 3-way SoD;
// 2. Premise retraction and Session-2 grant revocation racing between recall
//    preparation and recall consumption;
// 3. Concurrent ORG file revision advances racing against memory-to-ORG promotion.
module ContextEpistemicConsolidationGovernance {
  type ConsolidationCandidate = {
    proposer: str,
    evidenceOwner: str,
    approver: str,
    boundOutcome: str
  }

  type State = {
    liveOutcomes: Set[str],
    retractedOutcomes: Set[str],
    proposals: Set[ConsolidationCandidate],
    consolidated: Set[ConsolidationCandidate],
    session2GrantLive: bool,
    session2PreparedRecall: Set[ConsolidationCandidate],
    session2ActiveRecall: Set[ConsolidationCandidate],
    orgCurrentRev: int,
    orgWriteGrantLive: bool,
    promotedAtRev: Set[int]
  }

  pure val principals = Set("session1-agent", "runtime-eval", "human-curator")

  pure def distinctThreeWaySod(c: ConsolidationCandidate): bool =
    c.proposer != c.evidenceOwner and
      c.proposer != c.approver and
      c.evidenceOwner != c.approver

  var s41: State

  action init: bool =
    s41' = {
      liveOutcomes: Set(),
      retractedOutcomes: Set(),
      proposals: Set(),
      consolidated: Set(),
      session2GrantLive: true,
      session2PreparedRecall: Set(),
      session2ActiveRecall: Set(),
      orgCurrentRev: 1,
      orgWriteGrantLive: false,
      promotedAtRev: Set()
    }

  action recordAuthenticatedOutcome: bool = all {
    not(s41.retractedOutcomes.contains("out-1")),
    s41' = { ...s41, liveOutcomes: s41.liveOutcomes.union(Set("out-1")) }
  }

  action submitProposal(proposer: str, evOwner: str, approver: str): bool =
    s41' = {
      ...s41,
      proposals: s41.proposals.union(Set({
        proposer: proposer,
        evidenceOwner: evOwner,
        approver: approver,
        boundOutcome: "out-1"
      }))
    }

  action admitConsolidation(c: ConsolidationCandidate): bool = all {
    s41.proposals.contains(c),
    s41.liveOutcomes.contains(c.boundOutcome),
    not(s41.retractedOutcomes.contains(c.boundOutcome)),
    distinctThreeWaySod(c),
    s41' = { ...s41, consolidated: s41.consolidated.union(Set(c)) }
  }

  action prepareSession2Recall(c: ConsolidationCandidate): bool = all {
    s41.consolidated.contains(c),
    s41.session2GrantLive,
    s41.liveOutcomes.contains(c.boundOutcome),
    s41' = { ...s41, session2PreparedRecall: s41.session2PreparedRecall.union(Set(c)) }
  }

  action consumeSession2Recall(c: ConsolidationCandidate): bool = all {
    s41.session2PreparedRecall.contains(c),
    s41.session2GrantLive,
    s41.liveOutcomes.contains(c.boundOutcome),
    not(s41.retractedOutcomes.contains(c.boundOutcome)),
    s41' = { ...s41, session2ActiveRecall: s41.session2ActiveRecall.union(Set(c)) }
  }

  // Concurrent invalidation events: retract outcome or revoke Session-2 read grant
  action retractOutcome: bool = all {
    s41.liveOutcomes.contains("out-1"),
    s41' = {
      ...s41,
      liveOutcomes: s41.liveOutcomes.exclude(Set("out-1")),
      retractedOutcomes: s41.retractedOutcomes.union(Set("out-1")),
      session2ActiveRecall: Set()
      // Note: `consolidated` keeps historical lineage while active recall clears!
    }
  }

  action revokeSession2Grant: bool =
    s41' = {
      ...s41,
      session2GrantLive: false,
      session2ActiveRecall: Set()
    }

  action grantOrgWrite: bool =
    s41' = { ...s41, orgWriteGrantLive: true }

  action concurrentOrgEdit: bool = all {
    s41.orgCurrentRev < 2,
    s41' = { ...s41, orgCurrentRev: s41.orgCurrentRev + 1 }
  }

  action promoteToOrgExpectedRev(expectedRev: int): bool = all {
    s41.consolidated.size() > 0,
    s41.orgWriteGrantLive,
    expectedRev == s41.orgCurrentRev,
    s41' = {
      ...s41,
      orgCurrentRev: s41.orgCurrentRev + 1,
      promotedAtRev: s41.promotedAtRev.union(Set(expectedRev))
    }
  }

  // Genuine nondeterministic interleaving across sessions & source edits
  action step = any {
    recordAuthenticatedOutcome,
    { nondet p1 = principals.oneOf()
      nondet p2 = principals.oneOf()
      submitProposal("session1-agent", p1, p2) },
    { nondet c = s41.proposals.oneOf()
      admitConsolidation(c) },
    { nondet c = s41.consolidated.oneOf()
      any { prepareSession2Recall(c), consumeSession2Recall(c) } },
    retractOutcome,
    revokeSession2Grant,
    grantOrgWrite,
    concurrentOrgEdit,
    { nondet rev = Set(1, 2).oneOf()
      promoteToOrgExpectedRev(rev) },
    s41' = s41
  }

  // Temporal safety invariants
  val consolidatedInsightsBindLiveOutcomeAndDistinctRoles =
    s41.consolidated.forall(c =>
      distinctThreeWaySod(c) and
      (s41.liveOutcomes.contains(c.boundOutcome) or s41.retractedOutcomes.contains(c.boundOutcome))
    )

  val activeRecallFencedAgainstRetractionAndGrantLoss =
    s41.session2ActiveRecall.forall(c =>
      s41.session2GrantLive and
      s41.liveOutcomes.contains(c.boundOutcome) and
      not(s41.retractedOutcomes.contains(c.boundOutcome))
    )

  val orgPromotionRequiresExpectedRevisionAndWriteGrant =
    s41.promotedAtRev.size() == 0 or s41.orgWriteGrantLive

  val safety = and {
    consolidatedInsightsBindLiveOutcomeAndDistinctRoles,
    activeRecallFencedAgainstRetractionAndGrantLoss,
    orgPromotionRequiresExpectedRevisionAndWriteGrant
  }

  // Standalone fault-injection actions (outside `step`) for counterexample witnesses
  action buggyConsumeRecallAfterRetraction(c: ConsolidationCandidate): bool = all {
    s41.session2PreparedRecall.contains(c),
    s41' = { ...s41, session2ActiveRecall: s41.session2ActiveRecall.union(Set(c)) }
  }

  action buggyImplicitOrgPromoteWithoutWriteGrant: bool =
    s41' = { ...s41, promotedAtRev: s41.promotedAtRev.union(Set(s41.orgCurrentRev)) }

  run fullConsolidationRecallAndRetractionLineageTest = {
    val validCand = {
      proposer: "session1-agent",
      evidenceOwner: "runtime-eval",
      approver: "human-curator",
      boundOutcome: "out-1"
    }
    init
      .then(recordAuthenticatedOutcome)
      .then(submitProposal("session1-agent", "runtime-eval", "human-curator"))
      .then(admitConsolidation(validCand))
      .then(prepareSession2Recall(validCand))
      .then(consumeSession2Recall(validCand))
      .expect(s41.session2ActiveRecall.contains(validCand) and safety)
      .then(retractOutcome)
      .expect(
        s41.consolidated.contains(validCand) and
        s41.session2ActiveRecall.size() == 0 and
        safety
      )
  }

  run stalePreparedRecallAfterRetractionRaceCounterexampleTest = {
    val validCand = {
      proposer: "session1-agent",
      evidenceOwner: "runtime-eval",
      approver: "human-curator",
      boundOutcome: "out-1"
    }
    init
      .then(recordAuthenticatedOutcome)
      .then(submitProposal("session1-agent", "runtime-eval", "human-curator"))
      .then(admitConsolidation(validCand))
      .then(prepareSession2Recall(validCand))
      .then(retractOutcome)
      .then(buggyConsumeRecallAfterRetraction(validCand))
      .expect(not(activeRecallFencedAgainstRetractionAndGrantLoss))
  }

  run implicitOrgWriteWithoutGrantCounterexampleTest =
    init
      .then(buggyImplicitOrgPromoteWithoutWriteGrant)
      .expect(not(orgPromotionRequiresExpectedRevisionAndWriteGrant))
}
