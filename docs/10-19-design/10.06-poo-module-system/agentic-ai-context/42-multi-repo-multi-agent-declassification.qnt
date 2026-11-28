// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Slice 42 — Quint Nondeterministic Concurrent Interleaving Model ONLY:
// Per FormalVerificationTaxonomy in 42-multi-repo-multi-agent-declassification.sysml,
// pure redaction operator algebra and commitment non-collision live in 42-*.lean;
// this module explores nondeterministic races across multiple agents & repos:
// 1. Asynchronous certificate issuance vs confused-deputy / nested-subagent forwarding;
// 2. Concurrent Repo-Core cut advances or certificate revocations racing before and
//    after cross-repo delivery to Repo-SDK.
module MultiRepoAgentDeclassification {
  type Cert = {
    proposer: str,
    declassifier: str,
    recipient: str,
    boundOriginCut: int,
    boundDigest: str
  }

  type Delivery = {
    recipient: str,
    digest: str,
    viaCert: bool,
    cert: Cert
  }

  type State = {
    repoCoreCut: int,
    dualBindingsVerified: bool,
    directOriginGrants: Set[str],
    issuedCerts: Set[Cert],
    revokedCerts: Set[Cert],
    preparedDeliveries: Set[Delivery],
    activeDeliveries: Set[Delivery],
    historicalDeliveries: Set[Delivery]
  }

  pure val agents = Set("coord", "sec-officer", "sdk-agent", "nested-helper")
  pure val emptyCert: Cert = {
    proposer: "", declassifier: "", recipient: "", boundOriginCut: 0, boundDigest: ""
  }

  pure def validCertSoD(c: Cert): bool =
    c.proposer != c.declassifier and
      c.recipient != c.declassifier and
      c.proposer != c.recipient

  var s42: State

  action init: bool =
    s42' = {
      repoCoreCut: 1,
      dualBindingsVerified: true,
      directOriginGrants: Set("coord"),
      issuedCerts: Set(),
      revokedCerts: Set(),
      preparedDeliveries: Set(),
      activeDeliveries: Set(),
      historicalDeliveries: Set()
    }

  action issueDeclassificationCert(declassifier: str, recipient: str, digest: str): bool = {
    val c = {
      proposer: "coord",
      declassifier: declassifier,
      recipient: recipient,
      boundOriginCut: s42.repoCoreCut,
      boundDigest: digest
    }
    all {
      s42.issuedCerts.size() < 2,
      validCertSoD(c),
      digest == "redacted-d1",
      s42' = { ...s42, issuedCerts: s42.issuedCerts.union(Set(c)) }
    }
  }

  action prepareCertDelivery(c: Cert): bool = all {
    s42.dualBindingsVerified,
    s42.issuedCerts.contains(c),
    not(s42.revokedCerts.contains(c)),
    c.boundOriginCut == s42.repoCoreCut,
    c.boundDigest == "redacted-d1",
    s42' = {
      ...s42,
      preparedDeliveries: s42.preparedDeliveries.union(Set({
        recipient: c.recipient,
        digest: c.boundDigest,
        viaCert: true,
        cert: c
      }))
    }
  }

  action consumeDeliveryFence(d: Delivery): bool = all {
    s42.preparedDeliveries.contains(d),
    s42.dualBindingsVerified,
    if (d.viaCert) (
      validCertSoD(d.cert) and
      d.digest == "redacted-d1" and
      d.recipient == d.cert.recipient and
      d.cert.boundOriginCut == s42.repoCoreCut and
      not(s42.revokedCerts.contains(d.cert))
    ) else (
      s42.directOriginGrants.contains(d.recipient)
    ),
    s42' = {
      ...s42,
      activeDeliveries: s42.activeDeliveries.union(Set(d)),
      historicalDeliveries: s42.historicalDeliveries.union(Set(d))
    }
  }

  // Concurrent Repo-Core cut advance or certificate revocation cascades to active views
  action advanceRepoCoreCut: bool = all {
    s42.repoCoreCut < 2,
    s42' = {
      ...s42,
      repoCoreCut: s42.repoCoreCut + 1,
      activeDeliveries: s42.activeDeliveries.filter(d => not(d.viaCert))
    }
  }

  action revokeCert(c: Cert): bool = all {
    s42.issuedCerts.contains(c),
    s42' = {
      ...s42,
      revokedCerts: s42.revokedCerts.union(Set(c)),
      activeDeliveries: s42.activeDeliveries.filter(d => d.cert != c)
    }
  }

  // Genuine nondeterministic multi-agent & cut-advance exploration
  action step = any {
    { nondet officer = agents.oneOf()
      nondet target = Set("sdk-agent", "nested-helper").oneOf()
      nondet dig = Set("redacted-d1", "raw-secret").oneOf()
      issueDeclassificationCert(officer, target, dig) },
    { nondet c = s42.issuedCerts.oneOf()
      any { prepareCertDelivery(c), revokeCert(c) } },
    { nondet d = s42.preparedDeliveries.oneOf()
      consumeDeliveryFence(d) },
    advanceRepoCoreCut,
    s42' = s42
  }

  // Temporal safety invariants
  val noTransitiveGrantLeakOrRawExposure =
    s42.activeDeliveries.forall(d =>
      s42.directOriginGrants.contains(d.recipient) or
      (d.viaCert and d.digest == "redacted-d1")
    )

  val activeDeliverySatisfiesDistinctRoles =
    s42.activeDeliveries.forall(d =>
      not(d.viaCert) or (
        validCertSoD(d.cert) and
        d.recipient == d.cert.recipient and
        not(s42.revokedCerts.contains(d.cert))
      )
    )

  val originCutAdvanceWithdrawsActiveSubagentDelivery =
    s42.activeDeliveries.forall(d =>
      not(d.viaCert) or d.cert.boundOriginCut == s42.repoCoreCut
    )

  val safety = and {
    noTransitiveGrantLeakOrRawExposure,
    activeDeliverySatisfiesDistinctRoles,
    originCutAdvanceWithdrawsActiveSubagentDelivery
  }

  // Standalone fault-injection actions (outside `step`) for counterexample witnesses
  action buggyTransitiveForwardToNestedHelper(d: Delivery): bool = all {
    s42.activeDeliveries.contains(d),
    s42' = {
      ...s42,
      activeDeliveries: s42.activeDeliveries.union(Set({
        ...d,
        recipient: "nested-helper"
      }))
    }
  }

  action buggyConsumeStalePreparedAfterCutDrift(d: Delivery): bool = all {
    s42.preparedDeliveries.contains(d),
    s42' = { ...s42, activeDeliveries: s42.activeDeliveries.union(Set(d)) }
  }

  run declassifyDeliverAndCascadingCutWithdrawalSafeTest = {
    val c = {
      proposer: "coord",
      declassifier: "sec-officer",
      recipient: "sdk-agent",
      boundOriginCut: 1,
      boundDigest: "redacted-d1"
    }
    val d = { recipient: "sdk-agent", digest: "redacted-d1", viaCert: true, cert: c }
    init
      .then(issueDeclassificationCert("sec-officer", "sdk-agent", "redacted-d1"))
      .then(prepareCertDelivery(c))
      .then(consumeDeliveryFence(d))
      .expect(s42.activeDeliveries.contains(d) and safety)
      .then(advanceRepoCoreCut)
      .expect(
        s42.activeDeliveries.size() == 0 and
        s42.historicalDeliveries.contains(d) and
        safety
      )
  }

  run transitiveNestedSubagentForwardCounterexampleTest = {
    val c = {
      proposer: "coord",
      declassifier: "sec-officer",
      recipient: "sdk-agent",
      boundOriginCut: 1,
      boundDigest: "redacted-d1"
    }
    val d = { recipient: "sdk-agent", digest: "redacted-d1", viaCert: true, cert: c }
    init
      .then(issueDeclassificationCert("sec-officer", "sdk-agent", "redacted-d1"))
      .then(prepareCertDelivery(c))
      .then(consumeDeliveryFence(d))
      .then(buggyTransitiveForwardToNestedHelper(d))
      .expect(not(activeDeliverySatisfiesDistinctRoles))
  }

  run stalePreparedDeliveryAfterCutDriftCounterexampleTest = {
    val c = {
      proposer: "coord",
      declassifier: "sec-officer",
      recipient: "sdk-agent",
      boundOriginCut: 1,
      boundDigest: "redacted-d1"
    }
    val d = { recipient: "sdk-agent", digest: "redacted-d1", viaCert: true, cert: c }
    init
      .then(issueDeclassificationCert("sec-officer", "sdk-agent", "redacted-d1"))
      .then(prepareCertDelivery(c))
      .then(advanceRepoCoreCut)
      .then(buggyConsumeStalePreparedAfterCutDrift(d))
      .expect(not(originCutAdvanceWithdrawsActiveSubagentDelivery))
  }
}
