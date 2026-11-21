;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; Host-attested observations only. No action selection or execution authority.
(def evidence-checkpoint-fragment
 (ascent-fragment
  (relation requirement (requirement))
  (relation dependency (requirement parent))
  (relation contract (requirement identity))
  (relation receipt (receipt requirement contract outcome))
  (relation completed_outcome (outcome))
  (relation verified (receipt))
  (relation support_declaration (requirement contract scope declaration checker bindings commands dependencies))
  (relation support_witness (receipt scope declaration checker))
  (relation required_command (requirement contract command expected_exit))
  (relation binding_count (requirement contract count))
  (relation command_count (requirement contract count))
  (relation dependency_count (requirement contract count))
  (relation enumeration_gap (receipt reason))
  (relation closed_support (receipt))
  (relation binding (receipt key digest))
  (relation required_binding (requirement contract key))
  (relation current_binding (key digest))
  (relation command (receipt command expected_exit))
  (relation command_observation (receipt command exit timeout reaped quiet))
  (relation command_satisfied (receipt command))
  (relation prerequisite (receipt requirement parent_receipt))
  (relation quiescent (receipt))
  (relation material (receipt artifact))
  (relation available (receipt artifact))
  (relation withdrawn (receipt reason))
  (relation path (receipt parent_receipt))
  (relation historical_gap (receipt))
  (relation recorded_completion (receipt requirement))
  (relation historical_complete (requirement receipt))
  (relation direct_gap (receipt reason))
  (relation binding_gap (receipt key))
  (relation invalidated_by (receipt origin reason))
  (relation applicable (requirement receipt))
  (relation unavailable (receipt artifact))
  (relation reusable (requirement receipt))
  (relation unclosed (requirement))
  (relation material_gap (requirement receipt artifact))
  (relation completion_gap (requirement receipt))
  ((path E P) <-- (prerequisite E _ P))
  ((path E P) <-- (path E X) (path X P))
  ((binding_count R C N) <-- (support_declaration R C _ _ _ _ _ _)
    (aggregate N gerbil-ascent-count () (required_binding R C K)))
  ((command_count R C N) <-- (support_declaration R C _ _ _ _ _ _)
    (aggregate N gerbil-ascent-count () (required_command R C K X)))
  ((dependency_count R C N) <-- (support_declaration R C _ _ _ _ _ _)
    (aggregate N gerbil-ascent-count () (dependency R P)))
  ((closed_support E) <-- (receipt E R C _)
    (support_declaration R C S D V B M P) (support_witness E S D V)
    (binding_count R C B) (command_count R C M) (dependency_count R C P))
  ((enumeration_gap E (lit "declaration")) <-- (receipt E R C _)
    (not (support_declaration R C _ _ _ _ _ _)))
  ((enumeration_gap E (lit "witness-or-coverage")) <-- (receipt E _ _ _)
    (not (closed_support E)))
  ((command_satisfied E C) <-- (command E C Expected)
    (command_observation E C Actual (lit #f) (lit #t) (lit #t))
    (if (Actual Expected) (equal? Actual Expected)))
  ((historical_gap E) <-- (command E C _) (not (command_satisfied E C)))
  ((historical_gap E) <-- (receipt E R C _) (required_command R C K X)
    (not (command E K X)))
  ((historical_gap E) <-- (receipt E _ _ _) (not (verified E)))
  ((historical_gap E) <-- (receipt E _ _ _) (not (closed_support E)))
  ((recorded_completion E R) <-- (receipt E R _ O) (completed_outcome O))
  ((historical_gap E) <-- (receipt E _ _ O) (not (completed_outcome O)))
  ((historical_gap E) <-- (receipt E _ _ _) (path E E))
  ((historical_gap E) <-- (prerequisite E R P) (not (recorded_completion P R)))
  ((historical_gap E) <-- (prerequisite E _ P) (historical_gap P))
  ((historical_complete R E) <-- (recorded_completion E R) (not (historical_gap E)))
  ((direct_gap E (lit "contract")) <-- (receipt E R C _) (not (contract R C)))
  ((binding_gap E K) <-- (binding E K D) (not (current_binding K D)))
  ((binding_gap E K) <-- (receipt E R C _) (required_binding R C K) (not (binding E K _)))
  ((binding_gap E K) <-- (binding E K D) (current_binding K X)
    (if (D X) (not (equal? D X))))
  ((direct_gap E (lit "binding")) <-- (binding_gap E _))
  ((direct_gap E (lit "missing-binding")) <-- (receipt E R C _)
    (required_binding R C K) (not (binding E K _)))
  ((direct_gap E (lit "ambiguous-binding")) <-- (binding E K D)
    (current_binding K X) (if (D X) (not (equal? D X))))
  ((direct_gap E (lit "missing-prerequisite")) <-- (receipt E R _ _)
    (dependency R P) (not (prerequisite E P _)))
  ((direct_gap E (lit "changed-dependency")) <-- (receipt E R _ _)
    (prerequisite E P _) (not (dependency R P)))
  ((direct_gap E (lit "history")) <-- (receipt E _ _ _) (historical_gap E))
  ((direct_gap E (lit "enumeration")) <-- (enumeration_gap E _))
  ((direct_gap E Reason) <-- (receipt E _ _ _) (withdrawn E Reason))
  ((invalidated_by E E Reason) <-- (direct_gap E Reason))
  ((invalidated_by E Origin Reason) <-- (prerequisite E _ P) (invalidated_by P Origin Reason))
  ((applicable R E) <-- (requirement R) (historical_complete R E) (not (invalidated_by E _ _)))
  ((unavailable E A) <-- (material E A) (not (available E A)))
  ((reusable R E) <-- (applicable R E) (quiescent E) (not (unavailable E _)))
  ((unclosed R) <-- (requirement R) (not (applicable R _)))
  ((material_gap R E A) <-- (applicable R E) (unavailable E A))
  ((completion_gap R E) <-- (applicable R E) (not (quiescent E)))))

(def evidence-checkpoint-exchange-fragment
 (ascent-fragment
  (include evidence-checkpoint-fragment)
  (relation checkpoint_claim (claim requirement scope declaration_source))
  (relation checkpoint_source (source path digest))
  (relation checkpoint_receipt_source (receipt source))
  (relation checkpoint_resolved_receipt (receipt))
  (relation checkpoint_observation (id digest claim polarity source requirement scope state receipt))
  (relation checkpoint_dependency (claim parent_claim))
  (relation checkpoint_reason (claim receipt origin reason))
  ((checkpoint_resolved_receipt E) <--
    (checkpoint_receipt_source E S) (checkpoint_source S _ _))
  ;; A source association can be lost independently of the verified receipt.
  ;; Expose the missing trace using its declaration; do not erase history or
  ;; manufacture a report, a source match, or execution authority.
  ((checkpoint_observation E H C (lit "counter") Path R Scope
     (lit "provenance-unavailable") E) <--
    (checkpoint_claim C R Scope S) (receipt E R _ _)
    (checkpoint_source S Path H) (not (checkpoint_resolved_receipt E)))
  ((checkpoint_reason C E E (lit "receipt-source-unavailable")) <--
    (checkpoint_claim C R _ _) (receipt E R _ _)
    (not (checkpoint_resolved_receipt E)))
  ;; Query completion is intentionally absent: displaying a claim cannot
  ;; supply a receipt for that requirement or any of its dependents.
  ((checkpoint_observation E H C (lit "support") Path R Scope
     (lit "applicable") E) <--
    (checkpoint_claim C R Scope _) (applicable R E)
    (checkpoint_receipt_source E S) (checkpoint_source S Path H))
  ((checkpoint_observation E H C (lit "support") Path R Scope
     (lit "historical-only") E) <--
    (checkpoint_claim C R Scope _) (historical_complete R E)
    (not (applicable R E))
    (checkpoint_receipt_source E S) (checkpoint_source S Path H))
  ((checkpoint_observation C H C (lit "counter") Path R Scope
     (lit "unclosed") (lit "")) <--
    (checkpoint_claim C R Scope S) (requirement R) (unclosed R)
    (checkpoint_source S Path H))
  ((checkpoint_observation E H C (lit "counter") Path R Scope
     (lit "recorded-noncompletion") E) <--
    (checkpoint_claim C R Scope _) (receipt E R _ Outcome)
    (not (completed_outcome Outcome))
    (checkpoint_receipt_source E S) (checkpoint_source S Path H))
  ((checkpoint_reason C E Origin Reason) <--
    (checkpoint_claim C R _ _) (receipt E R _ _)
    (invalidated_by E Origin Reason))
  ((checkpoint_reason C E A (lit "artifact-unavailable")) <--
    (checkpoint_claim C R _ _) (material_gap R E A))
  ((checkpoint_reason C E E (lit "execution-unsettled")) <--
    (checkpoint_claim C R _ _) (completion_gap R E))
  ((checkpoint_dependency C Parent) <--
    (checkpoint_claim C R _ _) (dependency R P)
    (checkpoint_claim Parent P _ _))))

;; Work-completion witnesses are independent of task acceptance and read cuts.
;; Scope, actor incarnation, counter meaning and source are caller declarations.
(def evidence-progress-fragment
 (ascent-fragment
  (relation progress_contract (scope actor epoch kind source))
  (relation progress_active (scope actor epoch))
  (relation progress_cursor ((scope string?) (actor string?) (epoch string?)
    (kind string?) (source string?) (value exact-integer?)))
  (relation progress_sample ((id string?) (scope string?) (actor string?) (epoch string?)
    (kind string?) (source string?) (value exact-integer?)))
  (relation progress_attested (id))
  (relation progress_completed (id))
  (relation progress_conflict (id))
  (relation progress_matching (id))
  (relation progress_active_conflict (scope actor))
  (relation progress_cursor_conflict (scope actor epoch kind source))
  (relation progress_cursor_ready (scope actor epoch kind source value))
  (relation progress_value (scope actor epoch kind source value))
  (relation progress_dominated (scope actor epoch kind source value))
  (relation progress_frontier (scope actor epoch kind source value))
  (relation progress_advanced (scope actor epoch kind source previous value))
  (relation progress_rejected (id reason))
  ((progress_conflict I) <--
    (progress_sample I S A E K H N) (progress_sample I T B F L J M)
    (if (S A E K H N T B F L J M)
      (not (and (equal? S T) (equal? A B) (equal? E F)
                (equal? K L) (equal? H J) (equal? N M)))))
  ((progress_matching I) <-- (progress_sample I S A E K H _)
    (progress_contract S A E K H) (progress_active S A E)
    (not (progress_active_conflict S A)))
  ((progress_active_conflict S A) <-- (progress_active S A E) (progress_active S A F)
    (if (E F) (not (equal? E F))))
  ((progress_cursor_conflict S A E K H) <--
    (progress_cursor S A E K H N) (progress_cursor S A E K H M)
    (if (N M) (not (equal? N M))))
  ((progress_cursor_ready S A E K H B) <-- (progress_cursor S A E K H B)
    (not (progress_cursor_conflict S A E K H)) (if (B) (>= B 0)))
  ((progress_value S A E K H N) <--
    (progress_sample I S A E K H N) (progress_matching I)
    (progress_attested I) (progress_completed I) (not (progress_conflict I))
    (if (N) (>= N 0)))
  ((progress_dominated S A E K H N) <--
    (progress_value S A E K H N) (progress_value S A E K H M)
    (if (N M) (> M N)))
  ((progress_frontier S A E K H N) <--
    (progress_value S A E K H N) (not (progress_dominated S A E K H N)))
  ((progress_advanced S A E K H B N) <--
    (progress_frontier S A E K H N) (progress_cursor_ready S A E K H B)
    (if (B N) (and (>= B 0) (> N B))))
  ((progress_rejected I (lit "identity-or-contract")) <--
    (progress_sample I _ _ _ _ _ _) (not (progress_matching I)))
  ((progress_rejected I (lit "unattested")) <--
    (progress_sample I _ _ _ _ _ _) (not (progress_attested I)))
  ((progress_rejected I (lit "not-completed")) <--
    (progress_sample I _ _ _ _ _ _) (not (progress_completed I)))
  ((progress_rejected I (lit "conflicting-observation")) <-- (progress_conflict I))
  ((progress_rejected I (lit "invalid-counter")) <--
    (progress_sample I _ _ _ _ _ N)
    (if (N) (< N 0)))
  ((progress_rejected I (lit "cursor-unavailable-or-conflicting")) <--
    (progress_sample I S A E K H N) (progress_value S A E K H N)
    (not (progress_cursor_ready S A E K H _)))
  ((progress_rejected I (lit "replayed-or-regressed")) <--
    (progress_sample I S A E K H N) (progress_value S A E K H N)
    (progress_cursor S A E K H B) (if (B N)
      (and (>= B 0) (<= N B))))))

(define-program (make-evidence-checkpoint)
  (sources requirement dependency contract receipt completed_outcome verified
           support_declaration support_witness required_command
           binding required_binding current_binding command command_observation
           prerequisite quiescent material available withdrawn
           checkpoint_claim checkpoint_source checkpoint_receipt_source
           progress_contract progress_active progress_cursor progress_sample
           progress_attested progress_completed)
  (outputs historical_complete applicable reusable invalidated_by binding_gap enumeration_gap unclosed
           material_gap completion_gap checkpoint_observation checkpoint_dependency checkpoint_reason
           progress_frontier progress_advanced progress_rejected)
  (include evidence-checkpoint-exchange-fragment)
  (include evidence-progress-fragment))
