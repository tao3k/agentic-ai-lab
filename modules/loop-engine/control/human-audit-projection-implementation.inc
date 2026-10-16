;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;; Private source fragment included by human-audit.ss.
(def (loop-human-audit-validation-errors/contract-facts audit)
  (if (loop-human-audit? audit)
    (loop-human-audit-required-field-error/tail
     'name
     (loop-human-audit-name audit)
     (loop-human-audit-errors/tail
      (loop-human-audit-governor-contract-validation-errors
       (loop-human-audit-governor audit))
      (loop-human-audit-errors/tail
       (loop-human-audit-governor-contract-field-validation-errors
        (loop-human-audit-governor-contract audit))
       (loop-human-audit-field-validation-error/unless/tail
        (list? (loop-human-audit-state-facts audit))
        'state-facts
        'not-list
        (loop-human-audit-state-facts audit)
        (loop-human-audit-decisions-field-validation-errors
         (loop-human-audit-decisions audit))))))
    (list '((field . audit) (code . not-loop-human-audit)))))

(def (validate-loop-human-audit audit)
  (let (errors (loop-human-audit-validation-errors audit))
    (if (null? errors)
      audit
      (raise-control-plane-failure
       'loop-human-audit
       'invalid-loop-human-audit
       "invalid loop human audit"
       (list (cons 'errors errors))))))

(def (loop-human-audit-filter predicate values)
  (cond
   ((null? values) '())
   ((predicate (car values))
    (cons (car values)
          (loop-human-audit-filter predicate (cdr values))))
   (else
    (loop-human-audit-filter predicate (cdr values)))))

(def (loop-human-audit-name audit)
  (loop-human-audit-slot audit 'name #f))

(def (loop-human-audit-governor audit)
  (loop-human-audit-slot audit 'governor #f))

(def (loop-human-audit-governor-contract audit)
  (loop-human-audit-slot audit 'governor-contract #f))

(def (loop-human-audit-state-facts audit)
  (loop-human-audit-slot audit 'state-facts '()))

(def (loop-human-audit-decisions audit)
  (loop-human-audit-slot audit 'decisions '()))

(def (loop-human-audit-review-policy audit)
  (loop-human-audit-slot audit 'review-policy '()))

(def (loop-human-audit-governor-derived? audit)
  (loop-human-audit-slot audit 'governor-derived #f))

(def (loop-human-audit-governance-node-kind audit)
  (loop-human-audit-slot audit 'governance-node-kind #f))

(def (loop-human-audit-human-intervention? audit)
  (loop-human-audit-slot audit 'human-intervention #f))

(def (loop-human-audit-control-owner audit)
  (loop-human-audit-slot audit 'control-owner #f))

(def (loop-human-audit-decision? decision)
  (loop-human-audit-member? decision +loop-human-audit-decisions+))

(def (loop-human-audit-decision-ref audit pattern default)
  (let (found (assoc pattern (loop-human-audit-decisions audit)))
    (if found (cdr found) default)))

(def (loop-human-audit-review-item reason pattern action-key decision)
  (list (cons 'reason reason)
        (cons 'pattern pattern)
        (cons 'acting_on action-key)
        (cons 'decision decision)))

(def (loop-human-audit-inbox-item->review-item audit item)
  (let* ((pattern (loop-human-audit-alist-ref item 'pattern #f))
         (decision (loop-human-audit-decision-ref audit pattern 'pending)))
    (loop-human-audit-review-item
     (loop-human-audit-alist-ref item 'reason 'human-inbox)
     pattern
     (loop-human-audit-alist-ref item 'acting_on #f)
     decision)))

(def (loop-human-audit-open-pattern->review-item audit pattern)
  (loop-human-audit-review-item
   'actionable-pattern
   pattern
   #f
   (loop-human-audit-decision-ref audit pattern 'pending)))

(def (loop-human-audit-review-items audit)
  (let* ((valid-audit (validate-loop-human-audit audit))
         (governor (loop-human-audit-governor valid-audit))
         (state-facts (loop-human-audit-state-facts valid-audit))
         (contract (loop-governor->contract/validated governor state-facts)))
    (loop-human-audit-review-items/from-governor-contract
     valid-audit
     contract)))

(def (loop-human-audit-review-items/from-governor-contract audit contract)
  (loop-human-audit-open-review-items/tail
   audit
   (loop-human-audit-alist-ref contract 'open-patterns '())
   (loop-human-audit-inbox-review-items/tail
    audit
    (loop-human-audit-alist-ref contract 'human-inbox-items '())
    '())))

(def (loop-human-audit-open-review-items/tail audit patterns tail)
  (cond
   ((null? patterns) tail)
   (else
    (cons (loop-human-audit-open-pattern->review-item audit (car patterns))
          (loop-human-audit-open-review-items/tail
           audit
           (cdr patterns)
           tail)))))

(def (loop-human-audit-inbox-review-items/tail audit items tail)
  (cond
   ((null? items) tail)
   (else
    (cons (loop-human-audit-inbox-item->review-item audit (car items))
          (loop-human-audit-inbox-review-items/tail
           audit
           (cdr items)
           tail)))))

(def (loop-human-audit-patterns-by-decision audit decision)
  (loop-human-audit-patterns-by-decision/from-decisions
   (loop-human-audit-decisions audit)
   decision))

(def (loop-human-audit-patterns-by-decision/from-decisions decisions decision)
  (cond
   ((null? decisions) '())
   ((and (pair? (car decisions))
         (eq? (cdar decisions) decision))
    (cons (caar decisions)
          (loop-human-audit-patterns-by-decision/from-decisions
           (cdr decisions)
           decision)))
   (else
    (loop-human-audit-patterns-by-decision/from-decisions
     (cdr decisions)
     decision))))

(def (loop-human-audit-review-items-pending? review-items)
  (cond
   ((null? review-items) #f)
   ((eq? (loop-human-audit-alist-ref (car review-items)
                                     'decision
                                     'pending)
         'pending)
    #t)
   (else
    (loop-human-audit-review-items-pending? (cdr review-items)))))

(def (loop-human-audit-operation-status review-items)
  (if (loop-human-audit-review-items-pending? review-items)
    'waiting-human
    'completed))

(def (loop-human-audit-operation-id audit)
  (string->symbol
   (string-append
    "human-audit:"
    (symbol->string (loop-human-audit-name audit)))))

(def (loop-human-audit->agent-operation* audit review-items)
  (make-poo-flow-agent-operation
   (loop-human-audit-operation-id audit)
   'human-audit
   (list 'loop-human-audit (loop-human-audit-name audit))
   #f
   (list (cons 'schema +loop-human-audit-schema+)
         (cons 'review-items review-items)
         (cons 'decisions (loop-human-audit-decisions audit)))
   +loop-human-audit-schema+
   (list (cons 'target (loop-human-audit-execution-owner audit))
         (cons 'mode 'review-loop)
         (cons 'executes-runtime #f))
   (loop-human-audit-operation-status review-items)
   #f
   (list (cons 'governor-derived
               (loop-human-audit-governor-derived? audit))
         (cons 'governance-node-kind
               (loop-human-audit-governance-node-kind audit))
         (cons 'decision-owner
               (loop-human-audit-decision-owner audit)))))

(def (loop-human-audit->agent-operation audit)
  (let* ((valid-audit (validate-loop-human-audit audit))
         (review-items (loop-human-audit-review-items valid-audit)))
    (loop-human-audit->agent-operation* valid-audit review-items)))

(def (loop-human-audit->runtime-snapshot* audit review-items)
  (make-poo-flow-runtime-snapshot
   'human-audit
   (loop-human-audit-name audit)
   (loop-human-audit-operation-status review-items)
   #f
   (list (cons 'review-count (length review-items))
         (cons 'approved-patterns
               (loop-human-audit-patterns-by-decision audit 'approved))
         (cons 'rejected-patterns
               (loop-human-audit-patterns-by-decision audit 'rejected))
         (cons 'escalated-patterns
               (loop-human-audit-patterns-by-decision audit 'escalated))
         (cons 'changed-requested-patterns
               (loop-human-audit-patterns-by-decision
                audit
                'changes-requested)))
   #f
   '((stage . loop-human-audit->runtime-snapshot)
     (runtime-executed . #f)
     (projection-only . #t))
   (list (cons 'operation-id
               (loop-human-audit-operation-id audit))
         (cons 'decision-owner
               (loop-human-audit-decision-owner audit)))))

(def (loop-human-audit->runtime-snapshot audit)
  (let* ((valid-audit (validate-loop-human-audit audit))
         (review-items (loop-human-audit-review-items valid-audit)))
    (loop-human-audit->runtime-snapshot* valid-audit review-items)))

(def (loop-human-audit->contract/validated-governor-contract
      valid-audit
      governor-contract)
  (let* ((state-facts (loop-human-audit-state-facts valid-audit))
         (review-items
          (loop-human-audit-review-items/from-governor-contract
           valid-audit
           governor-contract))
         (agent-operation
          (loop-human-audit->agent-operation* valid-audit review-items))
         (runtime-snapshot
          (loop-human-audit->runtime-snapshot* valid-audit review-items)))
    (list (cons 'schema +loop-human-audit-schema+)
          (cons 'kind 'loop-human-audit)
          (cons 'name (loop-human-audit-name valid-audit))
          (cons 'governor-schema
                (loop-human-audit-alist-ref governor-contract 'schema #f))
          (cons 'governor governor-contract)
          (cons 'review-policy
                (loop-human-audit-review-policy valid-audit))
          (cons 'audit-boundary
                (list (cons 'governor-derived
                            (loop-human-audit-governor-derived? valid-audit))
                      (cons 'governance-node-kind
                            (loop-human-audit-governance-node-kind valid-audit))
                      (cons 'human-intervention
                            (loop-human-audit-human-intervention? valid-audit))
                      (cons 'agent-judgement-source
                            'consumed-governor-facts)))
          (cons 'audit-node
                (loop-governor-node->contract valid-audit))
          (cons 'review-items review-items)
          (cons 'review-count (length review-items))
          (cons 'agent-operation
                (poo-flow-agent-operation->alist agent-operation))
          (cons 'runtime-snapshot
                (poo-flow-runtime-snapshot->alist runtime-snapshot))
          (cons 'decisions (loop-human-audit-decisions valid-audit))
          (cons 'approved-patterns
                (loop-human-audit-patterns-by-decision valid-audit 'approved))
          (cons 'rejected-patterns
                (loop-human-audit-patterns-by-decision valid-audit 'rejected))
          (cons 'escalated-patterns
                (loop-human-audit-patterns-by-decision valid-audit 'escalated))
          (cons 'changed-requested-patterns
                (loop-human-audit-patterns-by-decision
                 valid-audit
                 'changes-requested))
          (cons 'state-facts state-facts)
          (cons 'runtime-boundary
                '((local-execution . validation-only)
                  (config-mutation . checked-interface-only)
                  (governor-inheritance . poo-c4)
                  (human-decision-state . review-loop)))
          (cons 'control-owner (loop-human-audit-control-owner valid-audit))
          (cons 'decision-owner (loop-human-audit-decision-owner valid-audit))
          (cons 'execution-owner (loop-human-audit-execution-owner valid-audit))
          (cons 'metadata (loop-human-audit-metadata valid-audit)))))

(def (loop-human-audit->contract audit)
  (let* ((provided-governor-contract
          (loop-human-audit-governor-contract audit))
         (valid-audit
          (if provided-governor-contract
            (validate-loop-human-audit/contract-facts audit)
            (validate-loop-human-audit audit)))
         (governor (loop-human-audit-governor valid-audit))
         (state-facts (loop-human-audit-state-facts valid-audit))
         (governor-contract
          (or provided-governor-contract
              (loop-governor->contract/validated governor state-facts))))
    (loop-human-audit->contract/validated-governor-contract
     valid-audit
     governor-contract)))
