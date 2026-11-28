-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
namespace OrgDurableDeclarations

structure ActivationKey where
  declaration : String
  stream : String
  occurrence : String
  deriving DecidableEq

structure Candidate where
  key : ActivationKey
  binding : String
  trusted : Bool

structure Owner where
  declaration : String
  stream : String
  binding : String
  enabled : Bool
  granted : Bool
  journal : ActivationKey → Option String

def Eligible (o : Owner) (c : Candidate) : Prop :=
  c.trusted = true ∧ o.enabled = true ∧ o.granted = true ∧
    c.key.declaration = o.declaration ∧ c.key.stream = o.stream ∧
    c.binding = o.binding ∧ o.journal c.key = none

def admit (o : Owner) (c : Candidate) (_gate : Eligible o c) : Owner :=
  { o with journal := fun k => if k = c.key then some c.binding else o.journal k }

theorem admitted_input_is_frozen (o : Owner) (c : Candidate) (gate : Eligible o c) :
    (admit o c gate).journal c.key = some c.binding := by
  simp [admit]

theorem replay_or_edit_cannot_admit_an_accepted_occurrence
    (o : Owner) (c : Candidate) (frozen : String)
    (prior : o.journal c.key = some frozen) : ¬ Eligible o c := by
  intro gate
  have absent := gate.2.2.2.2.2.2
  rw [prior] at absent
  contradiction

theorem stale_binding_cannot_admit (o : Owner) (c : Candidate)
    (stale : c.binding ≠ o.binding) : ¬ Eligible o c :=
  fun gate => stale gate.2.2.2.2.2.1

theorem revoked_owner_cannot_admit (o : Owner) (c : Candidate)
    (revoked : o.granted = false) : ¬ Eligible o c := by
  intro gate
  have allowed := gate.2.2.1
  rw [revoked] at allowed
  contradiction

theorem later_admission_retains_earlier_input (o : Owner) (c : Candidate)
    (gate : Eligible o c) (k : ActivationKey) (frozen : String)
    (prior : o.journal k = some frozen) : (admit o c gate).journal k = some frozen := by
  have different : k ≠ c.key := by
    intro same
    have absent := gate.2.2.2.2.2.2
    rw [same, absent] at prior
    contradiction
  simp [admit, different, prior]

end OrgDurableDeclarations

namespace AgenticOrgInquiry

structure Proposal where
  choice : String
  basis : Nat
  deriving DecidableEq

structure Inquiry where
  relevantBasis : Nat
  openQuestion : Bool
  granted : Bool
  proposals : List Proposal
  handoffs : String → Option Nat

def Eligible (q : Inquiry) (p : Proposal) : Prop :=
  q.openQuestion = true ∧ q.granted = true ∧ p.basis = q.relevantBasis ∧
    p ∈ q.proposals ∧ q.handoffs p.choice = none

def propose (q : Inquiry) (choice : String) : Inquiry :=
  { q with proposals := ⟨choice, q.relevantBasis⟩ :: q.proposals }

def accept (q : Inquiry) (p : Proposal) (_gate : Eligible q p) : Inquiry :=
  { q with handoffs := fun choice => if choice = p.choice then some p.basis else q.handoffs choice }

theorem proposal_preserves_journal (q : Inquiry) (choice : String) :
    (propose q choice).handoffs = q.handoffs := rfl

theorem stale_proposal_cannot_accept (q : Inquiry) (p : Proposal)
    (stale : p.basis ≠ q.relevantBasis) : ¬ Eligible q p :=
  fun gate => stale gate.2.2.1

theorem closed_question_cannot_accept (q : Inquiry) (p : Proposal)
    (closed : q.openQuestion = false) : ¬ Eligible q p := by
  intro gate
  exact Bool.noConfusion (closed.symm.trans gate.1)

theorem existing_handoff_blocks_implicit_repeat (q : Inquiry) (p : Proposal)
    (basis : Nat) (prior : q.handoffs p.choice = some basis) : ¬ Eligible q p := by
  intro gate
  have absent := gate.2.2.2.2
  rw [prior] at absent
  contradiction

theorem accepted_handoff_retains_its_basis (q : Inquiry) (p : Proposal)
    (gate : Eligible q p) : (accept q p gate).handoffs p.choice = some p.basis := by
  simp [accept]

end AgenticOrgInquiry

namespace AgendaNoticeAdmission

structure DeliveryKey where
  source : String
  notice : String
  commitmentOccurrence : String
  recipient : String
  deriving DecidableEq

structure Binding where
  source : String
  notice : String
  commitmentOccurrence : String
  ready : Bool
  armed : Bool
  dueAt : Nat
  startsAt : Nat
  basis : String
  audience : List String

structure Owner where
  current : Binding
  now : Nat
  mayNotify : String → String → Prop
  prepared : DeliveryKey → Option String
  journal : DeliveryKey → Option String

structure Eligible (o : Owner) (key : DeliveryKey) (basis : String) : Prop where
  ready : o.current.ready = true
  armed : o.current.armed = true
  current : basis = o.current.basis
  source : key.source = o.current.source
  notice : key.notice = o.current.notice
  occurrence : key.commitmentOccurrence = o.current.commitmentOccurrence
  inAudience : key.recipient ∈ o.current.audience
  allowed : o.mayNotify key.recipient basis
  due : o.current.dueAt ≤ o.now
  useful : o.now < o.current.startsAt
  unseen : o.journal key = none

def Prepared (o : Owner) (key : DeliveryKey) (basis : String) : Prop :=
  o.prepared key = some basis ∧ Eligible o key basis

def prepare (o : Owner) (key : DeliveryKey) (basis : String) (_gate : Eligible o key basis) :
    Owner :=
  { o with prepared := fun k => if k = key then some basis else o.prepared k }

def consume (o : Owner) (key : DeliveryKey) (basis : String) (_gate : Prepared o key basis) :
    Owner :=
  { o with
    prepared := fun k => if k = key then none else o.prepared k
    journal := fun k => if k = key then some basis else o.journal k }

def cancel (o : Owner) : Owner :=
  { o with current := { o.current with armed := false }, prepared := fun _ => none }

def replaceBinding (o : Owner) (next : Binding) : Owner :=
  { o with current := next, prepared := fun _ => none }

def ReceiptMatches (o : Owner) (key : DeliveryKey) (frozenBasis : String) : Prop :=
  o.journal key = some frozenBasis

theorem preparation_does_not_consume (o : Owner) (key : DeliveryKey) (basis : String)
    (gate : Eligible o key basis) : (prepare o key basis gate).journal = o.journal := rfl

theorem cancel_blocks_consumption_and_retains_journal (o : Owner) (key : DeliveryKey)
    (basis : String) : ¬ Prepared (cancel o) key basis ∧ (cancel o).journal = o.journal := by
  constructor
  · intro h
    have impossible : (none : Option String) = some basis := h.1
    cases impossible
  · rfl

theorem replacement_retires_preparation (o : Owner) (next : Binding) (key : DeliveryKey)
    (basis : String) : ¬ Prepared (replaceBinding o next) key basis :=
  by
    intro h
    have impossible : (none : Option String) = some basis := h.1
    cases impossible

theorem consumed_receipt_still_matches_after_cancel_or_edit (o : Owner) (next : Binding)
    (key : DeliveryKey) (basis : String) (gate : Prepared o key basis) :
    ReceiptMatches (cancel (consume o key basis gate)) key basis ∧
    ReceiptMatches (replaceBinding (consume o key basis gate) next) key basis := by
  simp [ReceiptMatches, cancel, consume, replaceBinding]

theorem stale_notice_cannot_reserve (o : Owner) (key : DeliveryKey) (basis : String)
    (stale : basis ≠ o.current.basis) : ¬ Eligible o key basis :=
  fun gate => stale gate.current

theorem unresolved_notice_cannot_reserve (o : Owner) (key : DeliveryKey) (basis : String)
    (unresolved : o.current.ready = false) : ¬ Eligible o key basis :=
  fun gate => Bool.noConfusion (unresolved.symm.trans gate.ready)

theorem expired_notice_cannot_reserve (o : Owner) (key : DeliveryKey) (basis : String)
    (expired : o.current.startsAt ≤ o.now) : ¬ Eligible o key basis :=
  fun gate => Nat.not_lt_of_ge expired gate.useful

theorem pending_receipt_cannot_authorize_repeat (o : Owner) (key : DeliveryKey)
    (priorBasis nextBasis : String) (prior : o.journal key = some priorBasis) :
    ¬ Eligible o key nextBasis := by
  intro gate
  have unseen := gate.unseen
  rw [prior] at unseen
  contradiction

theorem consume_preserves_other_recipients (o : Owner) (key other : DeliveryKey)
    (basis : String) (gate : Prepared o key basis) (different : other ≠ key) :
    (consume o key basis gate).journal other = o.journal other := by
  simp [consume, different]

structure Nonacceptance where
  key : DeliveryKey
  frozenBasis : String
  authenticated : Bool
  final : Bool
  fenced : Bool

def qualifiedNoSend (o : Owner) (key : DeliveryKey) (claim : Nonacceptance) : Bool :=
  decide (claim.key = key ∧ o.journal key = some claim.frozenBasis) &&
    claim.authenticated && claim.final && claim.fenced

inductive Assessment where
  | unknown | accepted | noSend | conflicted
  deriving DecidableEq

def assess (accepted noSend : Bool) : Assessment :=
  match accepted, noSend with
  | false, false => .unknown
  | true, false => .accepted
  | false, true => .noSend
  | true, true => .conflicted

inductive LinkedKind where
  | correction | replacement

def supported (kind : LinkedKind) (current : Assessment) : Prop :=
  match kind with
  | .correction => current = .accepted
  | .replacement => current = .noSend

def LinkedAllowed (original linked : DeliveryKey) (kind : LinkedKind)
    (proposalBasis current : Assessment) (authorized useful evidenceCurrent : Prop) : Prop :=
  linked ≠ original ∧ authorized ∧ useful ∧ proposalBasis = current ∧
    evidenceCurrent ∧ supported kind current

theorem unfenced_lookup_cannot_prove_no_send (o : Owner) (key : DeliveryKey)
    (claim : Nonacceptance) (unfenced : claim.fenced = false) :
    qualifiedNoSend o key claim = false := by
  simp [qualifiedNoSend, unfenced]

theorem wrong_recipient_cannot_prove_no_send (o : Owner) (key : DeliveryKey)
    (claim : Nonacceptance) (different : claim.key ≠ key) :
    qualifiedNoSend o key claim = false := by
  simp [qualifiedNoSend, different]

theorem unknown_cannot_support_linked_notice (original linked : DeliveryKey)
    (kind : LinkedKind) (basis : Assessment) (authorized useful evidenceCurrent : Prop) :
    ¬ LinkedAllowed original linked kind basis .unknown authorized useful evidenceCurrent := by
  cases kind <;> simp [LinkedAllowed, supported]

theorem conflict_blocks_linked_notice (original linked : DeliveryKey)
    (kind : LinkedKind) (basis : Assessment) (authorized useful evidenceCurrent : Prop) :
    ¬ LinkedAllowed original linked kind basis (assess true true) authorized useful evidenceCurrent := by
  cases kind <;> simp [LinkedAllowed, supported, assess]

theorem changed_assessment_rejects_old_proposal (original linked : DeliveryKey)
    (kind : LinkedKind) (basis current : Assessment) (authorized useful evidenceCurrent : Prop)
    (changed : basis ≠ current) :
    ¬ LinkedAllowed original linked kind basis current authorized useful evidenceCurrent :=
  fun h => changed h.2.2.2.1

theorem accepted_old_notice_cannot_authorize_replacement (original linked : DeliveryKey)
    (basis : Assessment) (authorized useful evidenceCurrent : Prop) :
    ¬ LinkedAllowed original linked .replacement basis (assess true false) authorized useful evidenceCurrent := by
  simp [LinkedAllowed, supported, assess]

theorem stale_evidence_blocks_even_same_assessment (original linked : DeliveryKey)
    (kind : LinkedKind) (current : Assessment) (authorized useful evidenceCurrent : Prop)
    (stale : ¬ evidenceCurrent) :
    ¬ LinkedAllowed original linked kind current current authorized useful evidenceCurrent :=
  fun h => stale h.2.2.2.2.1

structure CorrectionKey where
  original : DeliveryKey
  oldBasis : String
  materialChange : String
  deriving DecidableEq

def CorrectionReady (o : Owner) (used : CorrectionKey → Prop) (key : CorrectionKey)
    (current : Assessment) (changeCurrent authorized useful evidenceCurrent : Prop) : Prop :=
  ReceiptMatches o key.original key.oldBasis ∧ current = .accepted ∧
    changeCurrent ∧ authorized ∧ useful ∧ evidenceCurrent ∧ ¬ used key

def consumeCorrection (o : Owner) (used : CorrectionKey → Prop) (key : CorrectionKey)
    (current : Assessment) (changeCurrent authorized useful evidenceCurrent : Prop)
    (_gate : CorrectionReady o used key current changeCurrent authorized useful evidenceCurrent) :
    CorrectionKey → Prop :=
  fun k => k = key ∨ used k

theorem unknown_old_notice_cannot_correct (o : Owner) (used : CorrectionKey → Prop)
    (key : CorrectionKey) (changeCurrent authorized useful evidenceCurrent : Prop) :
    ¬ CorrectionReady o used key .unknown changeCurrent authorized useful evidenceCurrent := by
  simp [CorrectionReady]

theorem correction_consumption_blocks_repeat (o : Owner) (used : CorrectionKey → Prop)
    (key : CorrectionKey) (current : Assessment)
    (changeCurrent authorized useful evidenceCurrent : Prop)
    (gate : CorrectionReady o used key current changeCurrent authorized useful evidenceCurrent) :
    ¬ CorrectionReady o
      (consumeCorrection o used key current changeCurrent authorized useful evidenceCurrent gate)
      key current changeCurrent authorized useful evidenceCurrent := by
  simp [CorrectionReady, consumeCorrection]

theorem other_recipient_keeps_own_correction_key (o : Owner) (used : CorrectionKey → Prop)
    (key other : CorrectionKey) (current : Assessment)
    (changeCurrent authorized useful evidenceCurrent : Prop)
    (gate : CorrectionReady o used key current changeCurrent authorized useful evidenceCurrent)
    (different : other.original.recipient ≠ key.original.recipient) :
    consumeCorrection o used key current changeCurrent authorized useful evidenceCurrent gate other
      ↔ used other := by
  have distinct : other ≠ key := fun same => different (congrArg (·.original.recipient) same)
  simp [consumeCorrection, distinct]

end AgendaNoticeAdmission

namespace AgendaAuthoringAdmission

structure Selection where
  source : String
  effect : String
  resolved : Bool

structure Owner where
  current : Selection
  observed : String → Prop
  grants : String → Prop
  enabled : Bool
  consumed : Option String

structure MayConsume (o : Owner) (s : Selection) : Prop where
  enabled : o.enabled = true
  resolved : o.current.resolved = true
  sourceCurrent : s.source = o.current.source
  observed : o.observed s.source
  effectCurrent : s.effect = o.current.effect
  authorized : o.grants s.effect
  unseen : o.consumed = none

def publish (o : Owner) (next : Selection) : Owner :=
  { o with current := next }

theorem edit_does_not_grant_or_erase (o : Owner) (next : Selection) :
    (publish o next).grants = o.grants ∧ (publish o next).consumed = o.consumed :=
  ⟨rfl, rfl⟩

theorem stale_source_blocks_even_same_effect (o : Owner) (s : Selection)
    (stale : s.source ≠ o.current.source) : ¬ MayConsume o s :=
  fun gate => stale gate.sourceCurrent

theorem new_effect_requires_own_grant (o : Owner) (next : Selection)
    (notGranted : ¬ o.grants next.effect) : ¬ MayConsume (publish o next) next :=
  fun gate => notGranted gate.authorized

theorem same_effect_can_reuse_grant_after_rebinding (o : Owner) (next : Selection)
    (same : next.effect = o.current.effect) (granted : o.grants o.current.effect)
    (observed : o.observed next.source) (enabled : o.enabled = true)
    (resolved : next.resolved = true) (unseen : o.consumed = none) :
    MayConsume (publish o next) next :=
  ⟨enabled, resolved, rfl, observed, rfl, same.symm ▸ granted, unseen⟩

theorem rebinding_cannot_repeat_consumed_notice (o : Owner) (next : Selection) (oldEffect : String)
    (prior : o.consumed = some oldEffect) : ¬ MayConsume (publish o next) next := by
  intro gate
  have absent : o.consumed = none := gate.unseen
  rw [prior] at absent
  contradiction

end AgendaAuthoringAdmission
