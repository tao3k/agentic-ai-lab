// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 45 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 45-org-sexpr-gql-candidate-exchange-search.sysml,
// recursive ORG AST source-block pruning and multi-hop GQL walk induction live
// in 45-*.lean; this module explores nondeterministic races across:
// 1. Out-of-order GQL and ASCENT provider receipt arrivals (`complete` vs bounded);
// 2. Same-generation duplicate/retry collisions (`ReceiptUniqueness`);
// 3. Asynchronous `advanceTemporalGen` racing mid-join and post-publication.
module OrgSexprGqlCandidateExchange {
  type Receipt = {
    provider: str,
    gen: int,
    complete: bool
  }

  type State = {
    temporalGen: int,
    receipts: Set[Receipt],
    publishedAtGen: int,
    published: bool
  }

  pure val providers = Set("gql", "ascent")

  pure def hasCompleteAt(rs: Set[Receipt], prov: str, g: int): bool =
    rs.exists(r => r.provider == prov and r.gen == g and r.complete)

  var s45: State

  action init: bool =
    s45' = {
      temporalGen: 1,
      receipts: Set(),
      publishedAtGen: 0,
      published: false
    }

  // Provider submits at most one immutable receipt per `(provider, gen)`.
  action submitProviderReceipt(prov: str, g: int, isComplete: bool): bool = all {
    g <= s45.temporalGen,
    not(s45.receipts.exists(r => r.provider == prov and r.gen == g)),
    s45' = {
      ...s45,
      receipts: s45.receipts.union(Set({
        provider: prov,
        gen: g,
        complete: isComplete
      }))
    }
  }

  action publishCandidateExchange: bool = all {
    hasCompleteAt(s45.receipts, "gql", s45.temporalGen),
    hasCompleteAt(s45.receipts, "ascent", s45.temporalGen),
    s45' = {
      ...s45,
      published: true,
      publishedAtGen: s45.temporalGen
    }
  }

  action advanceTemporalGen: bool = all {
    s45.temporalGen < 2,
    s45' = {
      ...s45,
      temporalGen: s45.temporalGen + 1,
      published: false
      // `receipts` history is preserved!
    }
  }

  action step = any {
    { nondet p = providers.oneOf()
      nondet g = Set(1, 2).oneOf()
      nondet comp = Set(true, false).oneOf()
      submitProviderReceipt(p, g, comp) },
    publishCandidateExchange,
    advanceTemporalGen,
    s45' = s45
  }

  // Temporal safety invariants
  val publishedRequiresSameGenCompleteReceipts =
    not(s45.published) or (
      s45.publishedAtGen == s45.temporalGen and
      hasCompleteAt(s45.receipts, "gql", s45.temporalGen) and
      hasCompleteAt(s45.receipts, "ascent", s45.temporalGen)
    )

  val receiptUniquenessPerProviderGen =
    s45.receipts.forall(r1 =>
      s45.receipts.forall(r2 =>
        (r1.provider == r2.provider and r1.gen == r2.gen) implies r1 == r2
      )
    )

  val genAdvanceClearsPublicationPreservingHistory =
    not(s45.published) or s45.publishedAtGen == s45.temporalGen

  val safety = and {
    publishedRequiresSameGenCompleteReceipts,
    receiptUniquenessPerProviderGen,
    genAdvanceClearsPublicationPreservingHistory
  }

  // Standalone fault-injection actions (outside `step`) for race counterexamples
  action buggyPublishAcrossMismatchedGenerations: bool = all {
    s45.receipts.exists(r => r.provider == "gql" and r.complete),
    s45.receipts.exists(r => r.provider == "ascent" and r.complete),
    s45' = { ...s45, published: true, publishedAtGen: s45.temporalGen }
  }

  action buggyDuplicateConflictingRetry(prov: str): bool =
    s45' = {
      ...s45,
      receipts: s45.receipts.union(Set({
        provider: prov,
        gen: s45.temporalGen,
        complete: false
      }))
    }

  run sameGenCompletePublishAndGenAdvanceResetSafeTest =
    init
      .then(submitProviderReceipt("gql", 1, true))
      .then(submitProviderReceipt("ascent", 1, true))
      .then(publishCandidateExchange)
      .expect(s45.published and safety)
      .then(advanceTemporalGen)
      .expect(not(s45.published) and s45.receipts.size() == 2 and safety)

  run mixedGenerationJoinRaceCounterexampleTest =
    init
      .then(submitProviderReceipt("gql", 1, true))
      .then(advanceTemporalGen)
      .then(submitProviderReceipt("ascent", 2, true))
      .then(buggyPublishAcrossMismatchedGenerations)
      .expect(not(publishedRequiresSameGenCompleteReceipts))

  run conflictingSameGenRetryCounterexampleTest =
    init
      .then(submitProviderReceipt("gql", 1, true))
      .then(buggyDuplicateConflictingRetry("gql"))
      .expect(not(receiptUniquenessPerProviderGen))
}
