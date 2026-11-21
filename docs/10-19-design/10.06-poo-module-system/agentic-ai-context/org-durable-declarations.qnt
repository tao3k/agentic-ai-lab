// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// One declaration and trigger stream; 0 and 1 are nominal occurrences.
module OrgDurableDeclarations {
  type Candidate = { occurrence: int, binding: int, trusted: bool }
  type Acceptance = { occurrence: int, frozenBinding: int }
  type Owner = { binding: int, enabled: bool, granted: bool,
    inbox: Set[Candidate], journal: Set[Acceptance] }
  var s: Owner

  action init = s' = { binding: 0, enabled: true, granted: true,
    inbox: Set(), journal: Set() }

  pure def eligible(o: Owner, c: Candidate): bool =
    c.trusted and o.enabled and o.granted and c.binding == o.binding
      and not(o.journal.exists(a => a.occurrence == c.occurrence))

  action deliver(c: Candidate): bool =
    s' = { ...s, inbox: s.inbox.union(Set(c)) }

  action admit(c: Candidate): bool = all {
    s.inbox.contains(c), eligible(s, c),
    s' = { ...s, journal: s.journal.union(Set({ occurrence: c.occurrence,
      frozenBinding: c.binding })) }
  }

  action edit = all {
    s.binding == 0,
    s' = { ...s, binding: 1 }
  }
  action disarm = s' = { ...s, enabled: false }
  action revoke = s' = { ...s, granted: false }
  action recover = s' = s

  action step = any {
    { nondet occurrence = Set(0, 1).oneOf()
      nondet binding = Set(0, 1).oneOf()
      nondet trusted = Set(true, false).oneOf()
      deliver({ occurrence: occurrence, binding: binding, trusted: trusted }) },
    { nondet c = s.inbox.oneOf(); admit(c) },
    edit, disarm, revoke, recover
  }

  val oneAcceptancePerOccurrence = s.journal.forall(a =>
    s.journal.forall(b => a.occurrence != b.occurrence or a == b))
  val staleOrDisabledCannotAdmit = s.inbox.forall(c =>
    (c.binding != s.binding or not(s.enabled) or not(s.granted) or not(c.trusted))
      implies not(eligible(s, c)))
}

// One open inquiry. The cut represents its relevant premises, not all Context.
module AgenticOrgInquiry {
  type Proposal = { choice: str, basis: int }
  type Inquiry = { relevantBasis: int, open: bool, granted: bool,
    proposals: Set[Proposal], handoffs: Set[Proposal] }
  var q: Inquiry

  action init = q' = { relevantBasis: 0, open: true, granted: true,
    proposals: Set(), handoffs: Set() }

  pure def eligible(q: Inquiry, p: Proposal): bool =
    q.open and q.granted and p.basis == q.relevantBasis and q.proposals.contains(p)
      and not(q.handoffs.exists(h => h.choice == p.choice))

  action propose(choice: str): bool = all {
    q.open,
    q' = { ...q, proposals: q.proposals.union(Set({ choice: choice, basis: q.relevantBasis })) }
  }
  action accept(p: Proposal): bool = all {
    eligible(q, p),
    q' = { ...q, handoffs: q.handoffs.union(Set(p)) }
  }
  action relevantChange = all {
    q.relevantBasis == 0, q' = { ...q, relevantBasis: 1 }
  }
  action settle = q' = { ...q, open: false }
  action revoke = q' = { ...q, granted: false }
  action deferOrRecover = q' = q
  action step = any {
    propose("read-receipt"), propose("check-independent-record"),
    { nondet p = q.proposals.oneOf(); accept(p) },
    relevantChange, settle, revoke, deferOrRecover
  }
  val staleProposalCannotAccept = q.proposals.forall(p =>
    (p.basis != q.relevantBasis or not(q.open) or not(q.granted)) implies not(eligible(q, p)))
  val acceptedActionHasOneRetainedDecision = q.handoffs.forall(a =>
    q.handoffs.forall(b => a.choice != b.choice or a == b))
}

// One notice and commitment occurrence; separate keys for the illustrative recipients.
module AgendaNoticeAdmission {
  type Decision = { recipient: str, frozenBasis: int }
  type CorrectionKey = { original: Decision, change: str }
  type Agenda = { basis: int, ready: bool, armed: bool, cancelled: bool, now: int,
    dueAt: int, startsAt: int, grants: Set[str], approved: Set[Decision],
    prepared: Set[Decision], decisions: Set[Decision], providerAccepted: Set[Decision], finalNonacceptance: Set[Decision],
    correctionGrants: Set[str], consumedCorrections: Set[CorrectionKey] }
  val audience = Set("alice", "bob", "cara")
  var a: Agenda

  action init = a' = { basis: 0, ready: false, armed: false, cancelled: false, now: 0,
    dueAt: 1, startsAt: 3, grants: audience,
    approved: audience.map(r => { recipient: r, frozenBasis: 0 }), prepared: Set(), decisions: Set(), providerAccepted: Set(), finalNonacceptance: Set(),
    correctionGrants: Set(), consumedCorrections: Set() }

  pure def eligible(a: Agenda, basis: int, recipient: str): bool =
    a.ready and a.armed and not(a.cancelled) and basis == a.basis and recipient.in(a.grants)
      and recipient.in(audience) and a.approved.contains({ recipient: recipient, frozenBasis: basis })
      and a.dueAt <= a.now and a.now < a.startsAt
      and not(a.decisions.exists(d => d.recipient == recipient))

  action arm = all {
    not(a.cancelled), a' = { ...a, ready: true, armed: true }
  }
  action edit = all {
    a.basis == 0,
    a' = { ...a, basis: 1, ready: false, armed: false, dueAt: 2, prepared: Set() }
  }
  action cancel = a' = { ...a, armed: false, cancelled: true, prepared: Set() }
  action advance = all { a.now < 3, a' = { ...a, now: a.now + 1 } }
  action revoke(r: str): bool = a' = { ...a, grants: a.grants.exclude(Set(r)) }

  action approveCurrent(r: str): bool =
    a' = { ...a, approved: a.approved.union(Set({ recipient: r, frozenBasis: a.basis })) }

  action prepare(basis: int, recipient: str): bool = all {
    eligible(a, basis, recipient),
    a' = { ...a, prepared: a.prepared.union(Set({ recipient: recipient, frozenBasis: basis })) }
  }
  action consume(basis: int, recipient: str): bool = {
    val handoff = { recipient: recipient, frozenBasis: basis }
    all {
      a.prepared.contains(handoff), eligible(a, basis, recipient),
      a' = { ...a, prepared: a.prepared.exclude(Set(handoff)),
        decisions: a.decisions.union(Set(handoff)) }
    }
  }
  // An authenticated provider result names the exact consumed handoff.
  action acceptReceipt(handoff: Decision): bool = all {
    a.decisions.contains(handoff),
    a' = { ...a, providerAccepted: a.providerAccepted.union(Set(handoff)) }
  }
  action observeMissing = a' = a
  action admitNonacceptance(handoff: Decision, authenticated: bool, final: bool, fenced: bool): bool = all {
    a.decisions.contains(handoff), authenticated, final, fenced,
    a' = { ...a, finalNonacceptance: a.finalNonacceptance.union(Set(handoff)) }
  }
  pure def assessment(a: Agenda, h: Decision): str = {
    val accepted = a.providerAccepted.contains(h)
    val noSend = a.finalNonacceptance.contains(h)
    if (accepted and noSend) "conflicted"
    else if (accepted) "accepted"
    else if (noSend) "no-send"
    else "unknown"
  }
  // The proposed basis is rechecked against the current evidence at consumption.
  pure def linkedAllowed(a: Agenda, h: Decision, kind: str, basedOn: str,
      authorized: bool, useful: bool, distinctKey: bool, evidenceCurrent: bool): bool =
    authorized and useful and distinctKey and evidenceCurrent and a.decisions.contains(h)
      and basedOn == assessment(a, h)
      and ((kind == "correction" and basedOn == "accepted")
        or (kind == "replacement" and basedOn == "no-send"))
  // This fixture has one material change, distinct from the source cut.
  pure def correctionKey(h: Decision): CorrectionKey =
    { original: h, change: "start-moved-to-19" }
  pure def mayCorrect(a: Agenda, h: Decision, evidenceCurrent: bool): bool =
    a.basis == 1 and h.frozenBasis == 0 and a.ready and a.armed and not(a.cancelled)
      and a.now < a.startsAt and not(a.consumedCorrections.contains(correctionKey(h)))
      and linkedAllowed(a, h, "correction", "accepted",
        a.correctionGrants.contains(h.recipient) and a.grants.contains(h.recipient),
        true, true, evidenceCurrent)
  action grantCorrection(r: str): bool =
    a' = { ...a, correctionGrants: a.correctionGrants.union(Set(r)) }
  action consumeCorrection(h: Decision, evidenceCurrent: bool): bool = all {
    mayCorrect(a, h, evidenceCurrent),
    a' = { ...a, consumedCorrections: a.consumedCorrections.union(Set(correctionKey(h))) }
  }
  action recover = a' = a
  action step = any {
    arm, edit, cancel, advance, recover, observeMissing,
    { nondet r = audience.oneOf()
      nondet basis = Set(0, 1).oneOf()
      any { prepare(basis, r), consume(basis, r) } },
    { nondet r = audience.oneOf(); any { revoke(r), approveCurrent(r), grantCorrection(r) } },
    { nondet handoff = a.decisions.oneOf(); acceptReceipt(handoff) },
    { nondet handoff = a.decisions.oneOf()
      nondet evidenceCurrent = Set(true, false).oneOf()
      consumeCorrection(handoff, evidenceCurrent) },
    { nondet handoff = a.decisions.oneOf()
      nondet fenced = Set(true, false).oneOf()
      admitNonacceptance(handoff, true, true, fenced) }
  }

  val oneDecisionPerRecipient = a.decisions.forall(x =>
    a.decisions.forall(y => x.recipient != y.recipient or x == y))
  val unknownCannotRepeat = a.decisions.forall(d =>
    not(d.in(a.providerAccepted)) implies not(eligible(a, a.basis, d.recipient)))
  val receiptNamesConsumedHandoff = a.providerAccepted.subseteq(a.decisions)
  val cancelledCannotConsume = a.cancelled implies a.prepared == Set()
  val nonacceptanceNamesConsumedHandoff = a.finalNonacceptance.subseteq(a.decisions)
  val unresolvedCannotAuthorizeLinkedNotice = a.decisions.forall(h =>
    (assessment(a, h) == "unknown" or assessment(a, h) == "conflicted") implies
      not(Set("correction", "replacement").exists(kind =>
        linkedAllowed(a, h, kind, assessment(a, h), true, true, true, true))))
  val consumedCorrectionCannotRepeat = a.consumedCorrections.forall(k =>
    not(mayCorrect(a, k.original, true)))
}

// One recipient and occurrence. Source cuts and material effects vary independently.
module AgendaAuthoringAdmission {
  type Owner = { source: int, effect: str, resolved: bool, enabled: bool,
    observed: Set[int], grants: Set[str], consumed: Set[str] }
  var o: Owner

  action init = o' = { source: 0, effect: "team-at-18", resolved: false, enabled: true,
    observed: Set(), grants: Set(), consumed: Set() }

  pure def canConsume(o: Owner, source: int, effect: str): bool =
    o.enabled and o.resolved and source == o.source and o.observed.contains(source)
      and effect == o.effect and o.grants.contains(effect) and o.consumed == Set()

  action observe = o' = { ...o, observed: Set(o.source) }
  action resolve = o' = { ...o, resolved: true }
  // External authority admission, independent of the Org author.
  action grant(effect: str): bool = o' = { ...o, grants: o.grants.union(Set(effect)) }
  action revoke = o' = { ...o, grants: Set() }
  action cancel = o' = { ...o, enabled: false }
  // A published source observation may preserve or change the material effect.
  action publishEdit(nextEffect: str): bool = all {
    o.source == 0,
    o' = { ...o, source: 1, effect: nextEffect, resolved: nextEffect == o.effect and o.resolved }
  }
  action consume(source: int, effect: str): bool = all {
    canConsume(o, source, effect),
    o' = { ...o, consumed: Set(effect) }
  }

  action step = any {
    observe, resolve, revoke, cancel,
    grant("team-at-18"), grant("team-at-19"),
    publishEdit("team-at-18"), publishEdit("team-at-19"),
    { nondet source = Set(0, 1).oneOf()
      nondet effect = Set("team-at-18", "team-at-19").oneOf()
      consume(source, effect) }
  }
  val grantCoversCurrentEffect = not(o.grants.contains(o.effect)) implies
    not(canConsume(o, o.source, o.effect))
  val staleSelectionCannotConsume = Set(0, 1).forall(source =>
    source != o.source implies not(canConsume(o, source, o.effect)))
  val oneConsumedEffect = o.consumed.size() <= 1
}
