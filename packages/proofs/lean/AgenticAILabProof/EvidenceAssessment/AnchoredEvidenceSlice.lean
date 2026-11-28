/- Relational laws, not a theorem about natural-language factor extraction or
   the implementation's fidelity to this reference semantics. -/
namespace AgenticAILabProof.AnchoredEvidenceSlice

/- Optional factor-conjunction policy. Witness includes observation ID and digest.
   This is not a restriction on alternative caller-written association rules. -/
def conjunctiveMatch {Factor Witness : Type} (requested : Factor → Prop)
    (factor : Witness → Factor → Prop) (w : Witness) :=
  (∃ f, requested f) ∧ ∀ f, requested f → factor w f

theorem conjunctive_first_query_hit {Factor Witness : Type}
    (requested : Factor → Prop) (factor : Witness → Factor → Prop) (w : Witness)
    (nonempty : ∃ f, requested f) (sameWitness : ∀ f, requested f → factor w f) :
    conjunctiveMatch requested factor w := ⟨nonempty, sameWitness⟩

theorem conjunction_cannot_mix_witnesses {Factor Witness : Type}
    (requested : Factor → Prop) (factor : Witness → Factor → Prop)
    (noCommonWitness : ∀ w, ∃ f, requested f ∧ ¬ factor w f) :
    ¬ ∃ w, conjunctiveMatch requested factor w := by
  rintro ⟨w, _, allFactors⟩
  obtain ⟨f, needed, missing⟩ := noCommonWitness w
  exact missing (allFactors f needed)

theorem empty_anchors_do_not_select_everything {Factor Witness : Type}
    (factor : Witness → Factor → Prop) (w : Witness) :
    ¬ conjunctiveMatch (fun _ : Factor => False) factor w := by
  rintro ⟨⟨_, impossible⟩, _⟩
  exact impossible

/- Empty anchors may discover the available factor vocabulary. This branch
   supplies neither a matching witness nor a prescribed investigation. -/
def unboundDiscovery {Factor Witness : Type} (requested : Factor → Prop)
    (factor : Witness → Factor → Prop) (f : Factor) :=
  (¬ ∃ r, requested r) ∧ ∃ w, factor w f

theorem unbound_discovery_exact {Factor Witness : Type}
    (factor : Witness → Factor → Prop) (f : Factor) :
    unboundDiscovery (fun _ : Factor => False) factor f ↔ ∃ w, factor w f := by
  constructor
  · intro discovered
    exact discovered.2
  · intro known
    exact ⟨fun ⟨_, impossible⟩ => impossible, known⟩

theorem discovery_does_not_invent_a_hit {Factor Witness : Type}
    (requested : Factor → Prop) (factor : Witness → Factor → Prop)
    (f : Factor) (w : Witness) (discovered : unboundDiscovery requested factor f) :
    ¬ conjunctiveMatch requested factor w := by
  intro matched
  exact discovered.1 matched.1

theorem bound_query_is_not_unbound_discovery {Factor Witness : Type}
    (requested : Factor → Prop) (factor : Witness → Factor → Prop)
    (f : Factor) (bound : ∃ r, requested r) :
    ¬ unboundDiscovery requested factor f := fun discovered => discovered.1 bound

#print axioms conjunctive_first_query_hit
#print axioms conjunction_cannot_mix_witnesses
#print axioms empty_anchors_do_not_select_everything
#print axioms unbound_discovery_exact
#print axioms discovery_does_not_invent_a_hit
#print axioms bound_query_is_not_unbound_discovery

/- Rendering is not a recipient observation. These transport laws assume a
   calibrated UTF-8 receiver window, not that an LLM remembers a shown fact. -/
def delivered {Witness : Type} (rendered received : Witness → Prop) (w : Witness) :=
  rendered w ∧ received w

theorem rendering_does_not_prove_delivery {Witness : Type}
    (rendered received : Witness → Prop) (w : Witness) (missing : ¬ received w) :
    ¬ delivered rendered received w := fun shown => missing shown.2

theorem wire_within_calibrated_receiver (bytes window receiver : Nat)
    (framed : bytes ≤ window) (calibrated : window ≤ receiver) : bytes ≤ receiver :=
  Nat.le_trans framed calibrated

theorem overflowing_frame_strictly_reduces_budget (budget excess : Nat)
    (positive : 0 < budget) (overflow : 0 < excess) : budget - excess < budget :=
  Nat.sub_lt positive overflow

#print axioms rendering_does_not_prove_delivery
#print axioms wire_within_calibrated_receiver
#print axioms overflowing_frame_strictly_reduces_budget

def confirmedRead {Witness : Type} (verified : Bool) (prior : Witness → Prop) (w : Witness) :=
  verified = true ∧ prior w

theorem unverified_hint_cannot_suppress {Witness : Type} (prior : Witness → Prop)
    (w : Witness) : ¬ confirmedRead false prior w := by
  intro h
  cases h.1

theorem verified_hint_preserves_prior {Witness : Type} (prior : Witness → Prop)
    (w : Witness) : confirmedRead true prior w ↔ prior w := by
  exact ⟨fun h => h.2, fun h => ⟨rfl, h⟩⟩

#print axioms unverified_hint_cannot_suppress
#print axioms verified_hint_preserves_prior

def resumeRead {Query Witness : Type} (query : Query) (verified : Bool)
    (prior : Witness → Prop) : Query × (Witness → Prop) :=
  (query, confirmedRead verified prior)

theorem unconfirmed_read_preserves_query {Query Witness : Type}
    (query : Query) (prior : Witness → Prop) :
    (resumeRead query false prior).1 = query := rfl

#print axioms unconfirmed_read_preserves_query

def anchor {Factor Chain : Type} (exposed : Factor → Prop)
    (association : Factor → Chain → Prop) (applicable : Chain → Prop) (c : Chain) :=
  applicable c ∧ ∃ f, exposed f ∧ association f c

def slice {Factor Chain Witness : Type} (exposed : Factor → Prop)
    (association : Factor → Chain → Prop) (applicable : Chain → Prop)
    (belongs : Chain → Witness → Prop) (w : Witness) :=
  ∃ c, anchor exposed association applicable c ∧ belongs c w

structure Validity where
  sourceCurrent : Prop
  receiptBound : Prop
  conditionsSatisfied : Prop
  declarationValid : Prop
  evaluationComplete : Prop
  presentationSufficient : Prop

def Validity.ready (v : Validity) := v.sourceCurrent ∧ v.receiptBound ∧
  v.conditionsSatisfied ∧ v.declarationValid ∧ v.evaluationComplete ∧ v.presentationSufficient

def presented {Factor Chain Witness : Type} (v : Validity) (exposed : Factor → Prop)
    (association : Factor → Chain → Prop) (applicable : Chain → Prop)
    (belongs : Chain → Witness → Prop) (w : Witness) :=
  v.ready ∧ slice exposed association applicable belongs w

theorem declaration_without_receipt_cannot_present {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop) (w : Witness)
    (_registered : v.declarationValid) (missing : ¬ v.receiptBound) :
    ¬ presented v exposed association applicable belongs w := by
  intro h
  exact missing h.1.2.1

#print axioms declaration_without_receipt_cannot_present

theorem first_query_returns_associated_witness {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop)
    (f : Factor) (c : Chain) (w : Witness)
    (hv : v.ready) (hf : exposed f) (ha : association f c)
    (hc : applicable c) (hw : belongs c w) :
    presented v exposed association applicable belongs w :=
  ⟨hv, c, ⟨hc, f, hf, ha⟩, hw⟩

theorem returned_witness_has_trace {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop) (w : Witness)
    (h : presented v exposed association applicable belongs w) :
    ∃ c f, applicable c ∧ exposed f ∧ association f c ∧ belongs c w := by
  obtain ⟨_, c, ⟨hc, f, hf, ha⟩, hw⟩ := h
  exact ⟨c, f, hc, hf, ha, hw⟩

theorem invalid_binding_cannot_present {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop) (w : Witness)
    (invalid : ¬ v.ready) :
    ¬ presented v exposed association applicable belongs w := by
  intro h
  exact invalid h.1

theorem no_association_cannot_present {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop) (w : Witness)
    (missing : ∀ f c, exposed f → ¬ association f c) :
    ¬ presented v exposed association applicable belongs w := by
  intro h
  obtain ⟨c, f, _, hf, ha, _⟩ :=
    returned_witness_has_trace v exposed association applicable belongs w h
  exact missing f c hf ha

theorem malformed_declaration_cannot_present {Factor Chain Witness : Type}
    (v : Validity) (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop) (w : Witness)
    (invalid : ¬ v.declarationValid) :
    ¬ presented v exposed association applicable belongs w := by
  intro h
  obtain ⟨_, _, _, declared, _, _⟩ := h.1
  exact invalid declared

theorem family_closure_keeps_counterwitness {Factor Chain Witness : Type}
    (exposed : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop)
    (c : Chain) (counter : Witness) (hc : anchor exposed association applicable c)
    (hw : belongs c counter) : slice exposed association applicable belongs counter :=
  ⟨c, hc, hw⟩

theorem widening_preserves_evidence {Factor Chain Witness : Type}
    (small large : Factor → Prop) (association : Factor → Chain → Prop)
    (applicable : Chain → Prop) (belongs : Chain → Witness → Prop)
    (includes : ∀ f, small f → large f) (w : Witness)
    (h : slice small association applicable belongs w) :
    slice large association applicable belongs w := by
  obtain ⟨c, ⟨hc, f, hf, ha⟩, hw⟩ := h
  exact ⟨c, ⟨hc, f, includes f hf, ha⟩, hw⟩

def added {α : Type} (before now : α → Prop) (x : α) := now x ∧ ¬ before x

-- A read acknowledgement is not support: it only avoids re-presenting an
-- identical current unit under the same reading contract.
def refreshedRead {α : Type} (sameContract : Prop) (before current : α → Prop)
    (unit : α) : Prop := sameContract ∧ before unit ∧ current unit

theorem unchanged_unit_keeps_read {α : Type} (before current : α → Prop)
    (unit : α) (read : before unit) (present : current unit) :
    refreshedRead True before current unit := ⟨True.intro, read, present⟩

theorem withdrawn_unit_is_not_current_read {α : Type} (sameContract : Prop)
    (before current : α → Prop) (unit : α) (absent : ¬ current unit) :
    ¬ refreshedRead sameContract before current unit := fun h => absent h.2.2

theorem changed_read_contract_cannot_reuse_acknowledgement {α : Type}
    (before current : α → Prop) (unit : α) :
    ¬ refreshedRead False before current unit := fun h => h.1
def removed {α : Type} (before now : α → Prop) (x : α) := before x ∧ ¬ now x
def retained {α : Type} (before now : α → Prop) (x : α) := now x ∧ before x

theorem same_count_does_not_hide_replacement {α : Type} (before now : α → Prop)
    (old fresh : α) (ho : before old) (hn : ¬ now old)
    (hf : now fresh) (hb : ¬ before fresh) :
    removed before now old ∧ added before now fresh := ⟨⟨ho, hn⟩, ⟨hf, hb⟩⟩

theorem hidden_is_not_absent {α : Type} (facts visible : α → Prop)
    (existsFact : ∃ x, facts x) (_hidden : ∀ x, ¬ visible x) : ¬ (∀ x, ¬ facts x) := by
  obtain ⟨x, hx⟩ := existsFact
  intro absent
  exact absent x hx

def displayed {α : Type} (evidence : α → Prop)
    (fullBody summaryReference : Prop) (w : α) :=
  evidence w ∧ (fullBody ∨ summaryReference)

theorem honest_summary_preserves_hit {α : Type} (evidence : α → Prop)
    (fullBody summaryReference : Prop) (w : α)
    (hw : evidence w) (hs : summaryReference) :
    displayed evidence fullBody summaryReference w := ⟨hw, Or.inr hs⟩

def acknowledged (fullPresentation completeEvaluation : Prop) :=
  fullPresentation ∧ completeEvaluation

theorem collapsed_page_cannot_be_acknowledged (fullPresentation completeEvaluation : Prop)
    (collapsed : ¬ fullPresentation) : ¬ acknowledged fullPresentation completeEvaluation := by
  intro h
  exact collapsed h.1

/- Read acknowledgement is family-local, not an all-or-nothing page receipt.
   Changing scope does not change source-bound knowledge of displayed families. -/
def readSeen {α : Type} (before shown : α → Prop) (x : α) := before x ∨ shown x
def readPending {α : Type} (scope seen : α → Prop) (x : α) := scope x ∧ ¬ seen x

theorem fully_shown_family_is_acknowledged {α : Type} (before shown : α → Prop)
    (x : α) (h : shown x) : readSeen before shown x := Or.inr h

theorem hidden_family_is_not_newly_acknowledged {α : Type} (before shown : α → Prop)
    (x : α) (hb : ¬ before x) (hs : ¬ shown x) : ¬ readSeen before shown x := by
  intro h
  exact h.elim hb hs

theorem rescoping_does_not_replay_seen_family {α : Type} (scope seen : α → Prop)
    (x : α) (h : seen x) : ¬ readPending scope seen x := by
  intro pending
  exact pending.2 h

theorem read_progress_preserves_previous_families {α : Type} (before shown : α → Prop)
    (x : α) (h : before x) : readSeen before shown x := Or.inl h

theorem folded_unseen_family_remains_pending {α : Type} (scope before shown : α → Prop)
    (x : α) (hc : scope x) (hb : ¬ before x) (hs : ¬ shown x) :
    readPending scope (readSeen before shown) x :=
  ⟨hc, hidden_family_is_not_newly_acknowledged before shown x hb hs⟩

theorem outside_scope_is_not_a_pending_removal {α : Type} (scope before now : α → Prop)
    (x : α) (h : ¬ scope x) : ¬ (scope x ∧ removed before now x) := by
  intro r
  exact h r.1

/- Grouping pending references changes presentation, not source-bound reads. -/
def groupedReference {α : Type} (scope before shown inline : α → Prop) (x : α) :=
  readPending scope (readSeen before shown) x ∧ ¬ inline x

theorem pending_reference_partition {α : Type} (scope before shown inline : α → Prop)
    (x : α) : readPending scope (readSeen before shown) x ↔
    (readPending scope (readSeen before shown) x ∧ inline x) ∨
      groupedReference scope before shown inline x := by
  classical
  constructor
  · intro h
    by_cases hi : inline x
    · exact Or.inl ⟨h, hi⟩
    · exact Or.inr ⟨h, hi⟩
  · intro h
    exact h.elim And.left And.left

theorem grouped_reference_cannot_acknowledge {α : Type}
    (scope before shown inline : α → Prop) (x : α)
    (h : groupedReference scope before shown inline x) :
    ¬ readSeen before shown x := h.1.2

/- Retain query intent, not a frozen answer or a prescribed investigation. -/
def restoreQuery {Q : Type} (saved requested : Option Q) : Option Q :=
  requested.orElse fun _ => saved

theorem checkpoint_only_restores_query {Q : Type} (q : Q) :
    restoreQuery (some q) none = some q := rfl

theorem explicit_query_owns_scope {Q : Type} (saved : Option Q) (q : Q) :
    restoreQuery saved (some q) = some q := rfl

theorem missing_query_is_not_invented {Q : Type} :
    restoreQuery (none : Option Q) none = none := rfl

theorem query_override_composes {Q : Type} (saved a b : Option Q) :
    restoreQuery (restoreQuery saved a) b = restoreQuery saved (restoreQuery a b) := by
  cases b <;> cases a <;> rfl

def resumedAnswer {Q F A : Type} (derive : Q → F → A)
    (saved requested : Option Q) (current : F) : Option A :=
  (restoreQuery saved requested).map fun q => derive q current

theorem recovery_reevaluates_current_facts {Q F A : Type}
    (derive : Q → F → A) (q : Q) (current : F) :
    resumedAnswer derive (some q) none current = some (derive q current) := rfl

theorem changed_answer_is_not_a_frozen_replay {Q F A : Type}
    (derive : Q → F → A) (q : Q) (before current : F)
    (changed : derive q before ≠ derive q current) :
    resumedAnswer derive (some q) none current ≠ some (derive q before) := by
  intro replay
  exact changed (Option.some.inj replay).symm

end AgenticAILabProof.AnchoredEvidenceSlice
