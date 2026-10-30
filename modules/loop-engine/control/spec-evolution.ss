;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: spec evolution proposals are review-only control-plane facts.
;;; Invariant: this module never mutates config, schedules loops, or executes runtime work.

(import :yuanxu/composition/roles
        (only-in :clan/poo/object .o object?)
        :yuanxu/modules/funflow/control-plane/roles
        :yuanxu/modules/funflow/control-plane/failure
        :yuanxu/object-family/role-syntax
        (only-in :agentic-ai-lab/modules/loop-engine/control/human-audit
                 +loop-human-audit-decisions+))

(export +spec-evolution-feedback-schema+
        +spec-evolution-proposal-schema+
        +spec-evolution-review-schema+
        +spec-evolution-manifest-row-schema+
        +spec-evolution-target-kinds+
        spec-evolution-feedback-role
        spec-evolution-proposal-role
        spec-evolution-review-role
        external-feedback-receipt-prototype
        spec-change-proposal-prototype
        spec-evolution-review-item-prototype
        make-external-feedback-receipt
        external-feedback-receipt?
        external-feedback-receipt-slot
        external-feedback-receipt-id
        external-feedback-receipt-source
        external-feedback-receipt-signals
        external-feedback-receipt->alist
        make-spec-change-proposal
        spec-change-proposal?
        spec-change-proposal-slot
        spec-change-proposal-id
        spec-change-proposal-target-kind
        spec-change-proposal-target-ref
        spec-change-proposal-change-kind
        spec-change-proposal-feedback-receipts
        spec-change-proposal-direct-mutation?
        spec-change-proposal->alist
        make-spec-evolution-review-item
        spec-evolution-review-item?
        spec-evolution-review-item-slot
        spec-evolution-review-item-decision
        spec-evolution-review-item->alist
        spec-change-proposal->human-audit-review-item
        spec-evolution-review-item->human-audit-review-item
        spec-evolution-review-item->runtime-manifest-row
        validate-external-feedback-receipt
        validate-spec-change-proposal
        validate-spec-evolution-review-item)

;; : Symbol
(def +spec-evolution-feedback-schema+
  'agentic-ai-lab.spec-evolution.external-feedback-receipt.v1)

;; : Symbol
(def +spec-evolution-proposal-schema+
  'agentic-ai-lab.spec-evolution.spec-change-proposal.v1)

;; : Symbol
(def +spec-evolution-review-schema+
  'agentic-ai-lab.spec-evolution.review-item.v1)

;; : Symbol
(def +spec-evolution-manifest-row-schema+
  'agentic-ai-lab.spec-evolution.runtime-manifest-row.v1)

;; : [Symbol]
(def +spec-evolution-target-kinds+
  '(spec profile eval policy))

;;; Field-row construction is a projection helper, not a user DSL. Keeping the
;;; row keys at the call site lets review and runtime manifest projections stay
;;; auditable while avoiding repeated alist boilerplate.
;; spec-evolution-field-rows
;;   : (-> FieldRowClause... Alist)
;;   | contract: lowers fixed projection clauses to ordinary alist rows
;;   | doc m%
;;       # Examples
;;       ```scheme
;;       (spec-evolution-field-rows (kind 'review) (runtime-executed #f))
;;       ;; => ((kind . review) (runtime-executed . #f))
;;       ```
;;     %
(defrules spec-evolution-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;; : (-> Unit Role)
(def spec-evolution-feedback-role
  (.o (:: @ receipt-role)
      (name 'spec-evolution-feedback)
      (kind 'evidence)
      (responsibility 'external-feedback-evidence)
      (runtime-owner 'gerbil)))

;; : (-> Unit Role)
(def spec-evolution-proposal-role
  (.o (:: @ control-plane-role)
      (name 'spec-evolution-proposal)
      (kind 'policy-proposal)
      (responsibility 'spec-profile-eval-policy-delta)
      (runtime-owner 'gerbil)
      (mutation-boundary 'human-audit-required)))

;; : (-> Unit Role)
(def spec-evolution-review-role
  (.o (:: @ spec-evolution-proposal-role)
      (name 'spec-evolution-review)
      (kind 'review-projection)
      (responsibility 'human-audit-review-item)
      (decision-owner 'human)
      (execution-owner 'marlin-agent-core)))

;; : (-> Unit ExternalFeedbackReceiptPrototype)
(def external-feedback-receipt-prototype
  (poo-core-role-object
   (slots ((schema +spec-evolution-feedback-schema+)
           (kind 'external-feedback-receipt)
           (receipt-id #f)
           (source #f)
           (signals '())
           (summary #f)
           (metadata '())
           (runtime-executed #f)))
   (supers spec-evolution-feedback-role)))

;; : (-> Unit SpecChangeProposalPrototype)
(def spec-change-proposal-prototype
  (poo-core-role-object
   (slots ((schema +spec-evolution-proposal-schema+)
           (kind 'spec-change-proposal)
           (proposal-id #f)
           (target-kind #f)
           (target-ref #f)
           (change-kind #f)
           (summary #f)
           (feedback-receipts '())
           (proposed-by 'developer-feedback-loop)
           (mutation-boundary 'human-audit-required)
           (direct-mutation #f)
           (runtime-executed #f)
           (metadata '())))
   (supers spec-evolution-proposal-role)))

;; : (-> Unit SpecEvolutionReviewItemPrototype)
(def spec-evolution-review-item-prototype
  (poo-core-role-object
   (slots ((schema +spec-evolution-review-schema+)
           (kind 'spec-evolution-review-item)
           (proposal #f)
           (decision 'pending)
           (reason 'spec-evolution-proposal)
           (review-owner 'human-audit)
           (decision-owner 'human)
           (execution-owner 'marlin-agent-core)
           (direct-mutation #f)
           (runtime-executed #f)
           (metadata '())))
   (supers spec-evolution-review-role)))

;; : (-> Alist Alist Alist)
(def (spec-evolution-slot-rows/tail rows tail)
  (append rows tail))

;; : (-> Object Symbol Value Value)
(def (spec-evolution-slot object slot default)
  (role-slot/default object slot default))

;; : (-> Object Boolean)
(def (spec-evolution-stable-id? value)
  (symbol? value))

;; : (-> Object Boolean)
(def (spec-evolution-string? value)
  (string? value))

;; : (-> Object [Object] Boolean)
(def (spec-evolution-member? value values)
  (cond
   ((null? values) #f)
   ((equal? value (car values)) #t)
   (else (spec-evolution-member? value (cdr values)))))

;; : (-> Predicate [Object] Boolean)
(def (spec-evolution-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (spec-evolution-every? predicate (cdr values)))
   (else #f)))

;; : (-> Symbol Source [Alist] String [Alist] ExternalFeedbackReceipt)
(def (make-external-feedback-receipt receipt-id
                                     source
                                     signals
                                     summary
                                     . maybe-metadata)
  (poo-core-role-object
   (slot-rows
    (spec-evolution-slot-rows/tail
     (list (cons 'receipt-id receipt-id)
           (cons 'source source)
           (cons 'signals signals)
           (cons 'summary summary))
     (list (cons 'metadata
                 (if (null? maybe-metadata) '() (car maybe-metadata))))))
   (supers external-feedback-receipt-prototype)))

;; : (-> Object Boolean)
(def (external-feedback-receipt? receipt)
  (and (object? receipt)
       (eq? (external-feedback-receipt-slot receipt 'kind #f)
            'external-feedback-receipt)))

;; : (-> ExternalFeedbackReceipt Symbol Value Value)
(def (external-feedback-receipt-slot receipt slot default)
  (spec-evolution-slot receipt slot default))

;; : (-> ExternalFeedbackReceipt Symbol)
(def (external-feedback-receipt-id receipt)
  (external-feedback-receipt-slot receipt 'receipt-id #f))

;; : (-> ExternalFeedbackReceipt Symbol)
(def (external-feedback-receipt-source receipt)
  (external-feedback-receipt-slot receipt 'source #f))

;; : (-> ExternalFeedbackReceipt [Alist])
(def (external-feedback-receipt-signals receipt)
  (external-feedback-receipt-slot receipt 'signals '()))

;; : (-> SpecChangeProposal Symbol Symbol Symbol String [ExternalFeedbackReceipt] SpecChangeProposal)
(def (make-spec-change-proposal proposal-id
                                target-kind
                                target-ref
                                change-kind
                                summary
                                feedback-receipts
                                . maybe-metadata)
  (poo-core-role-object
   (slot-rows
    (spec-evolution-slot-rows/tail
     (list (cons 'proposal-id proposal-id)
           (cons 'target-kind target-kind)
           (cons 'target-ref target-ref)
           (cons 'change-kind change-kind)
           (cons 'summary summary)
           (cons 'feedback-receipts feedback-receipts))
     (list (cons 'metadata
                 (if (null? maybe-metadata) '() (car maybe-metadata))))))
   (supers spec-change-proposal-prototype)))

;; : (-> Object Boolean)
(def (spec-change-proposal? proposal)
  (and (object? proposal)
       (eq? (spec-change-proposal-slot proposal 'kind #f)
            'spec-change-proposal)))

;; : (-> SpecChangeProposal Symbol Value Value)
(def (spec-change-proposal-slot proposal slot default)
  (spec-evolution-slot proposal slot default))

;; : (-> SpecChangeProposal Symbol)
(def (spec-change-proposal-id proposal)
  (spec-change-proposal-slot proposal 'proposal-id #f))

;; : (-> SpecChangeProposal Symbol)
(def (spec-change-proposal-target-kind proposal)
  (spec-change-proposal-slot proposal 'target-kind #f))

;; : (-> SpecChangeProposal Symbol)
(def (spec-change-proposal-target-ref proposal)
  (spec-change-proposal-slot proposal 'target-ref #f))

;; : (-> SpecChangeProposal Symbol)
(def (spec-change-proposal-change-kind proposal)
  (spec-change-proposal-slot proposal 'change-kind #f))

;; : (-> SpecChangeProposal [ExternalFeedbackReceipt])
(def (spec-change-proposal-feedback-receipts proposal)
  (spec-change-proposal-slot proposal 'feedback-receipts '()))

;; : (-> SpecChangeProposal Boolean)
(def (spec-change-proposal-direct-mutation? proposal)
  (spec-change-proposal-slot proposal 'direct-mutation #f))

;; : (-> SpecChangeProposal Symbol SpecEvolutionReviewItem)
(def (make-spec-evolution-review-item proposal decision . maybe-metadata)
  (poo-core-role-object
   (slot-rows
    (spec-evolution-slot-rows/tail
     (list (cons 'proposal proposal)
           (cons 'decision decision))
     (list (cons 'metadata
                 (if (null? maybe-metadata) '() (car maybe-metadata))))))
   (supers spec-evolution-review-item-prototype)))

;; : (-> Object Boolean)
(def (spec-evolution-review-item? item)
  (and (object? item)
       (eq? (spec-evolution-review-item-slot item 'kind #f)
            'spec-evolution-review-item)))

;; : (-> SpecEvolutionReviewItem Symbol Value Value)
(def (spec-evolution-review-item-slot item slot default)
  (spec-evolution-slot item slot default))

;; : (-> SpecEvolutionReviewItem Symbol)
(def (spec-evolution-review-item-decision item)
  (spec-evolution-review-item-slot item 'decision 'pending))

;; : (-> ExternalFeedbackReceipt [ValidationError])
(def (external-feedback-receipt-validation-errors receipt)
  (if (external-feedback-receipt? receipt)
    (spec-evolution-field-error/unless/tail
     (spec-evolution-stable-id? (external-feedback-receipt-id receipt))
     'receipt-id
     'not-symbol
     (external-feedback-receipt-id receipt)
     (spec-evolution-field-error/unless/tail
      (symbol? (external-feedback-receipt-source receipt))
      'source
      'not-symbol
      (external-feedback-receipt-source receipt)
      (spec-evolution-field-error/unless/tail
       (list? (external-feedback-receipt-signals receipt))
       'signals
       'not-list
       (external-feedback-receipt-signals receipt)
       '())))
    (list '((field . receipt) (code . not-external-feedback-receipt)))))

;; : (-> SpecChangeProposal [ValidationError])
(def (spec-change-proposal-validation-errors proposal)
  (if (spec-change-proposal? proposal)
    (spec-evolution-field-error/unless/tail
     (spec-evolution-stable-id? (spec-change-proposal-id proposal))
     'proposal-id
     'not-symbol
     (spec-change-proposal-id proposal)
     (spec-evolution-field-error/unless/tail
      (spec-evolution-member? (spec-change-proposal-target-kind proposal)
                              +spec-evolution-target-kinds+)
      'target-kind
      'unsupported-target-kind
      (spec-change-proposal-target-kind proposal)
      (spec-evolution-field-error/unless/tail
       (symbol? (spec-change-proposal-target-ref proposal))
       'target-ref
       'not-symbol
       (spec-change-proposal-target-ref proposal)
       (spec-evolution-field-error/unless/tail
        (symbol? (spec-change-proposal-change-kind proposal))
        'change-kind
        'not-symbol
        (spec-change-proposal-change-kind proposal)
        (spec-evolution-field-error/unless/tail
         (spec-evolution-string?
          (spec-change-proposal-slot proposal 'summary #f))
         'summary
         'not-string
         (spec-change-proposal-slot proposal 'summary #f)
         (spec-evolution-field-error/unless/tail
          (spec-evolution-every?
           external-feedback-receipt?
           (spec-change-proposal-feedback-receipts proposal))
          'feedback-receipts
          'not-external-feedback-receipts
          (spec-change-proposal-feedback-receipts proposal)
          (spec-evolution-field-error/unless/tail
           (not (spec-change-proposal-direct-mutation? proposal))
           'direct-mutation
           'must-remain-false
           (spec-change-proposal-direct-mutation? proposal)
           '())))))))
    (list '((field . proposal) (code . not-spec-change-proposal)))))

;; : (-> SpecEvolutionReviewItem [ValidationError])
(def (spec-evolution-review-item-validation-errors item)
  (if (spec-evolution-review-item? item)
    (let ((proposal (spec-evolution-review-item-slot item 'proposal #f))
          (decision (spec-evolution-review-item-decision item)))
      (spec-evolution-errors/tail
       (spec-change-proposal-validation-errors proposal)
       (spec-evolution-field-error/unless/tail
        (spec-evolution-member? decision +loop-human-audit-decisions+)
        'decision
        'unsupported-decision
        decision
        (spec-evolution-field-error/unless/tail
         (not (spec-evolution-review-item-slot item 'direct-mutation #f))
         'direct-mutation
         'must-remain-false
         (spec-evolution-review-item-slot item 'direct-mutation #f)
         '()))))
    (list '((field . review-item) (code . not-spec-evolution-review-item)))))

;; : (-> Boolean Symbol Symbol FieldValue [ValidationError] [ValidationError])
(def (spec-evolution-field-error/unless/tail valid? field code value tail)
  (if valid?
    tail
    (cons (list (cons 'field field)
                (cons 'code code)
                (cons 'value value))
          tail)))

;; : (-> [ValidationError] [ValidationError] [ValidationError])
(def (spec-evolution-errors/tail errors tail)
  (if (null? errors)
    tail
    (cons (car errors)
          (spec-evolution-errors/tail (cdr errors) tail))))

;; : (-> ExternalFeedbackReceipt ExternalFeedbackReceipt)
(def (validate-external-feedback-receipt receipt)
  (let (errors (external-feedback-receipt-validation-errors receipt))
    (if (null? errors)
      receipt
      (raise-control-plane-failure
       'spec-evolution
       'invalid-external-feedback-receipt
       "invalid external feedback receipt"
       (list (cons 'errors errors))))))

;; : (-> SpecChangeProposal SpecChangeProposal)
(def (validate-spec-change-proposal proposal)
  (let (errors (spec-change-proposal-validation-errors proposal))
    (if (null? errors)
      proposal
      (raise-control-plane-failure
       'spec-evolution
       'invalid-spec-change-proposal
       "invalid spec change proposal"
       (list (cons 'errors errors))))))

;; : (-> SpecEvolutionReviewItem SpecEvolutionReviewItem)
(def (validate-spec-evolution-review-item item)
  (let (errors (spec-evolution-review-item-validation-errors item))
    (if (null? errors)
      item
      (raise-control-plane-failure
       'spec-evolution
       'invalid-spec-evolution-review-item
       "invalid spec evolution review item"
       (list (cons 'errors errors))))))

;; : (-> ExternalFeedbackReceipt Alist)
(def (external-feedback-receipt->alist receipt)
  (let (valid-receipt (validate-external-feedback-receipt receipt))
    (spec-evolution-field-rows
     (schema (external-feedback-receipt-slot valid-receipt 'schema #f))
     (kind (external-feedback-receipt-slot valid-receipt 'kind #f))
     (receipt-id (external-feedback-receipt-id valid-receipt))
     (source (external-feedback-receipt-source valid-receipt))
     (signals (external-feedback-receipt-signals valid-receipt))
     (summary (external-feedback-receipt-slot valid-receipt 'summary #f))
     (metadata (external-feedback-receipt-slot valid-receipt 'metadata '()))
     (runtime-executed (external-feedback-receipt-slot
                        valid-receipt
                        'runtime-executed
                        #f)))))

;; : (forall (receipt) (-> [receipt] [Alist]))
;; : (-> SpecChangeProposal Alist)
(def (spec-change-proposal->alist proposal)
  (let (valid-proposal (validate-spec-change-proposal proposal))
    (spec-evolution-field-rows
     (schema (spec-change-proposal-slot valid-proposal 'schema #f))
     (kind (spec-change-proposal-slot valid-proposal 'kind #f))
     (proposal-id (spec-change-proposal-id valid-proposal))
     (target-kind (spec-change-proposal-target-kind valid-proposal))
     (target-ref (spec-change-proposal-target-ref valid-proposal))
     (change-kind (spec-change-proposal-change-kind valid-proposal))
     (summary (spec-change-proposal-slot valid-proposal 'summary #f))
     (feedback-receipts
      (map external-feedback-receipt->alist
           (spec-change-proposal-feedback-receipts valid-proposal)))
     (proposed-by (spec-change-proposal-slot valid-proposal
                                             'proposed-by
                                             #f))
     (mutation-boundary (spec-change-proposal-slot valid-proposal
                                                   'mutation-boundary
                                                   #f))
     (direct-mutation (spec-change-proposal-direct-mutation?
                       valid-proposal))
     (runtime-executed (spec-change-proposal-slot valid-proposal
                                                  'runtime-executed
                                                  #f))
     (metadata (spec-change-proposal-slot valid-proposal 'metadata '())))))

;; : (-> SpecEvolutionReviewItem Alist)
(def (spec-evolution-review-item->alist item)
  (let* ((valid-item (validate-spec-evolution-review-item item))
         (proposal (spec-evolution-review-item-slot valid-item 'proposal #f)))
    (spec-evolution-field-rows
     (schema (spec-evolution-review-item-slot valid-item 'schema #f))
     (kind (spec-evolution-review-item-slot valid-item 'kind #f))
     (proposal (spec-change-proposal->alist proposal))
     (decision (spec-evolution-review-item-decision valid-item))
     (reason (spec-evolution-review-item-slot valid-item 'reason #f))
     (review-owner (spec-evolution-review-item-slot valid-item
                                                    'review-owner
                                                    #f))
     (decision-owner (spec-evolution-review-item-slot valid-item
                                                      'decision-owner
                                                      #f))
     (execution-owner (spec-evolution-review-item-slot valid-item
                                                       'execution-owner
                                                       #f))
     (direct-mutation (spec-evolution-review-item-slot valid-item
                                                       'direct-mutation
                                                       #f))
     (runtime-executed (spec-evolution-review-item-slot valid-item
                                                        'runtime-executed
                                                        #f))
     (metadata (spec-evolution-review-item-slot valid-item 'metadata '())))))

;; : (-> SpecChangeProposal Alist)
(def (spec-change-proposal->human-audit-review-item proposal)
  (let (valid-proposal (validate-spec-change-proposal proposal))
    (spec-evolution-field-rows
     (reason 'spec-evolution-proposal)
     (pattern (spec-change-proposal-id valid-proposal))
     (acting_on (spec-change-proposal-target-ref valid-proposal))
     (target-kind (spec-change-proposal-target-kind valid-proposal))
     (change-kind (spec-change-proposal-change-kind valid-proposal))
     (decision 'pending)
     (direct-mutation #f)
     (runtime-executed #f))))

;; : (-> SpecEvolutionReviewItem Alist)
(def (spec-evolution-review-item->human-audit-review-item item)
  (let* ((valid-item (validate-spec-evolution-review-item item))
         (proposal (spec-evolution-review-item-slot valid-item 'proposal #f))
         (review-row (spec-change-proposal->human-audit-review-item proposal)))
    (spec-evolution-field-rows
     (reason (cdr (assoc 'reason review-row)))
     (pattern (cdr (assoc 'pattern review-row)))
     (acting_on (cdr (assoc 'acting_on review-row)))
     (target-kind (cdr (assoc 'target-kind review-row)))
     (change-kind (cdr (assoc 'change-kind review-row)))
     (decision (spec-evolution-review-item-decision valid-item))
     (direct-mutation #f)
     (runtime-executed #f))))

;; : (-> SpecEvolutionReviewItem Alist)
(def (spec-evolution-review-item->runtime-manifest-row item)
  (let* ((valid-item (validate-spec-evolution-review-item item))
         (proposal (spec-evolution-review-item-slot valid-item 'proposal #f))
         (decision (spec-evolution-review-item-decision valid-item)))
    (spec-evolution-field-rows
     (schema +spec-evolution-manifest-row-schema+)
     (kind 'spec-evolution-runtime-manifest-row)
     (proposal-id (spec-change-proposal-id proposal))
     (target-kind (spec-change-proposal-target-kind proposal))
     (target-ref (spec-change-proposal-target-ref proposal))
     (change-kind (spec-change-proposal-change-kind proposal))
     (human-audit-required #t)
     (human-audit-decision decision)
     (eligible-for-checked-mutation (eq? decision 'approved))
     (direct-mutation #f)
     (runtime-owner 'marlin-agent-core)
     (runtime-executed #f))))
