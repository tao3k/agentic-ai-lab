;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable recovery diagnostics and observability support.
;;; Invariant: this owner normalizes receipt rows only; scenario construction
;;; and public projection stay in durable-recovery-scenario.ss.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store)

(export +agentic-ai-lab-durable-recovery-scenario-diagnostic-schema+
        +agentic-ai-lab-durable-recovery-observability-schema+
        +agentic-ai-lab-durable-recovery-stages+
        agentic-ai-lab-durable-recovery-option
        agentic-ai-lab-durable-recovery-runtime-store-row
        agentic-ai-lab-durable-recovery-runtime-store-ref
        agentic-ai-lab-durable-recovery-diagnostics
        agentic-ai-lab-durable-recovery-observability-rows)

(def +agentic-ai-lab-durable-recovery-scenario-diagnostic-schema+
  'agentic-ai-lab.module-system.durable-recovery-scenario.diagnostic.v1)

(def +agentic-ai-lab-durable-recovery-observability-schema+
  'agentic-ai-lab.module-system.durable-recovery-scenario.observability.v1)

(def +agentic-ai-lab-durable-recovery-stages+
  '(durable-event-append
    checkpoint-read
    derived-index-rebuild
    job-lease-claim
    repair-event-append
    recovery-decision))

;; : (forall (a) (-> Alist Symbol a a))
(def (agentic-ai-lab-durable-recovery-alist-ref row key default-value)
  (if (list? row)
    (let (entry (assoc key row))
      (if entry (cdr entry) default-value))
    default-value))

;; : (forall (a) (-> Alist Symbol a a))
(def (agentic-ai-lab-durable-recovery-option options key default-value)
  (agentic-ai-lab-durable-recovery-alist-ref options key default-value))

;; : (-> Procedure List Boolean)
(def (agentic-ai-lab-durable-recovery-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (agentic-ai-lab-durable-recovery-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> (List a) (List a) (List a)))
(def (agentic-ai-lab-durable-recovery-reverse-onto values tail)
  (if (null? values)
    tail
    (agentic-ai-lab-durable-recovery-reverse-onto
     (cdr values)
     (cons (car values) tail))))

;; : (forall (a) (-> a (List a) Boolean))
(def (agentic-ai-lab-durable-recovery-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-recovery-alist? value)
  (list? value))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-recovery-row-valid? row)
  (eq? (agentic-ai-lab-durable-recovery-alist-ref row 'valid? #f) #t))

;; : (-> Symbol Symbol Symbol Alist Alist)
(def (agentic-ai-lab-durable-recovery-diagnostic code slot severity payload)
  (list
   (cons 'kind +agentic-ai-lab-durable-recovery-scenario-diagnostic-schema+)
   (cons 'schema +agentic-ai-lab-durable-recovery-scenario-diagnostic-schema+)
   (cons 'code code)
   (cons 'phase 'durable-recovery-scenario)
   (cons 'slot slot)
   (cons 'severity severity)
   (cons 'payload payload)
   (cons 'recoverable?
         (agentic-ai-lab-durable-recovery-option payload 'recoverable? #t))
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol Datum [Alist])
(def (agentic-ai-lab-durable-recovery-required-symbol-diagnostics code slot value)
  (if (symbol? value)
    '()
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      code
      slot
      'error
      (list (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t))))))

;; : (-> Datum Alist)
(def (agentic-ai-lab-durable-recovery-runtime-store-row runtime-store-receipt)
  (cond
   ((agentic-ai-lab-durable-runtime-store-contract-receipt?
     runtime-store-receipt)
    (agentic-ai-lab-durable-runtime-store-contract-receipt->alist
     runtime-store-receipt))
   ((list? runtime-store-receipt) runtime-store-receipt)
   (else runtime-store-receipt)))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-durable-recovery-runtime-store-diagnostics runtime-store-row)
  (cond
   ((not (agentic-ai-lab-durable-recovery-alist? runtime-store-row))
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'invalid-runtime-store-receipt
      'runtime-store-row
      'error
      (list (cons 'value runtime-store-row)
            (cons 'recoverable? #t)))))
   ((not (eq? (agentic-ai-lab-durable-recovery-alist-ref
               runtime-store-row
               'kind
               #f)
              'agentic-ai-lab.durable.runtime-store-contract-receipt))
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'invalid-runtime-store-receipt
      'runtime-store-row
      'error
      (list (cons 'kind
                  (agentic-ai-lab-durable-recovery-alist-ref
                   runtime-store-row
                   'kind
                   #f))
            (cons 'recoverable? #t)))))
   ((agentic-ai-lab-durable-recovery-row-valid? runtime-store-row) '())
   (else
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'runtime-store-receipt-invalid
      'runtime-store-row
      'error
      (list (cons 'diagnostics
                  (agentic-ai-lab-durable-recovery-alist-ref
                   runtime-store-row
                   'diagnostics
                   '()))
            (cons 'recoverable? #t)))))))

;; : (-> Alist Symbol Value)
(def (agentic-ai-lab-durable-recovery-runtime-store-ref runtime-store-row key)
  (agentic-ai-lab-durable-recovery-alist-ref runtime-store-row key #f))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-durable-recovery-replayable-task? task-row)
  (let (action-class
        (agentic-ai-lab-durable-recovery-alist-ref
         task-row
         'action-class
         #f))
    (or (eq? action-class 'replayable)
        (eq? action-class 'idempotent))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-durable-recovery-compensated-task? task-row)
  (not
   (null?
    (agentic-ai-lab-durable-recovery-alist-ref
     task-row
     'compensation-refs
     '()))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-durable-recovery-task-has-checkpoint? task-row)
  (if (agentic-ai-lab-durable-recovery-alist-ref task-row 'checkpoint-ref #f)
    #t
    #f))

;; : (-> Symbol Symbol [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-action-class-diagnostics/tail task-id
                                                              action-class
                                                              tail)
  (if (agentic-ai-lab-durable-recovery-member?
       action-class
       +yuanxu-durable-action-classes+)
    tail
    (cons
     (agentic-ai-lab-durable-recovery-diagnostic
      'unsupported-action-class
      'workflow-task-rows
      'error
      (list (cons 'task task-id)
            (cons 'action-class action-class)
            (cons 'allowed +yuanxu-durable-action-classes+)
            (cons 'recoverable? #t)))
     tail)))

;; : (-> Alist Symbol Symbol [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-checkpoint-diagnostics/tail task-row
                                                            task-id
                                                            action-class
                                                            tail)
  (if (or (eq? action-class 'idempotent)
          (agentic-ai-lab-durable-recovery-task-has-checkpoint? task-row))
    tail
    (cons
     (agentic-ai-lab-durable-recovery-diagnostic
      'missing-task-checkpoint
      'workflow-task-rows
      'error
      (list (cons 'task task-id)
            (cons 'action-class action-class)
            (cons 'recoverable? #t)))
     tail)))

;; : (-> Alist Symbol Symbol [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-compensation-diagnostics/tail task-row
                                                              task-id
                                                              action-class
                                                              tail)
  (if (or (agentic-ai-lab-durable-recovery-replayable-task? task-row)
          (agentic-ai-lab-durable-recovery-compensated-task? task-row)
          (agentic-ai-lab-durable-recovery-task-has-checkpoint? task-row))
    tail
    (cons
     (agentic-ai-lab-durable-recovery-diagnostic
      'non-idempotent-without-compensation
      'workflow-task-rows
      'error
      (list (cons 'task task-id)
            (cons 'action-class action-class)
            (cons 'recoverable? #t)))
     tail)))

;; : (-> Alist Symbol Symbol [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-manual-replay-diagnostics/tail task-row
                                                               task-id
                                                               action-class
                                                               tail)
  (if (or (not (agentic-ai-lab-durable-recovery-member?
                action-class
                '(terminal manual)))
          (agentic-ai-lab-durable-recovery-compensated-task? task-row))
    tail
    (cons
     (agentic-ai-lab-durable-recovery-diagnostic
      'unsafe-manual-replay
      'workflow-task-rows
      'error
      (list (cons 'task task-id)
            (cons 'action-class action-class)
            (cons 'recoverable? #t)))
     tail)))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-durable-recovery-workflow-task-diagnostics/one task-row)
  (let ((action-class
         (agentic-ai-lab-durable-recovery-alist-ref
          task-row
          'action-class
          #f))
        (task-id
         (agentic-ai-lab-durable-recovery-alist-ref
          task-row
          'durable-task-id
          (agentic-ai-lab-durable-recovery-alist-ref task-row 'check #f))))
    (agentic-ai-lab-durable-recovery-action-class-diagnostics/tail
     task-id
     action-class
     (agentic-ai-lab-durable-recovery-checkpoint-diagnostics/tail
      task-row
      task-id
      action-class
      (agentic-ai-lab-durable-recovery-compensation-diagnostics/tail
       task-row
       task-id
       action-class
       (agentic-ai-lab-durable-recovery-manual-replay-diagnostics/tail
        task-row
        task-id
        action-class
        '()))))))

;; : (-> [Alist] [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-workflow-task-diagnostics/rev task-rows
                                                              diagnostics-rev)
  (if (null? task-rows)
    diagnostics-rev
    (agentic-ai-lab-durable-recovery-workflow-task-diagnostics/rev
     (cdr task-rows)
     (agentic-ai-lab-durable-recovery-reverse-onto
      (agentic-ai-lab-durable-recovery-workflow-task-diagnostics/one
       (car task-rows))
      diagnostics-rev))))

;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-workflow-task-diagnostics task-rows)
  (if (list? task-rows)
    (reverse
     (agentic-ai-lab-durable-recovery-workflow-task-diagnostics/rev
      task-rows
      '()))
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'invalid-workflow-task-rows
      'workflow-task-rows
      'error
      (list (cons 'value task-rows)
            (cons 'recoverable? #t))))))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics/one row)
  (if (and (agentic-ai-lab-durable-recovery-alist? row)
           (eq? (agentic-ai-lab-durable-recovery-alist-ref row 'kind #f)
                'agentic-ai-lab.memory-core.durable-job-receipt)
           (agentic-ai-lab-durable-recovery-row-valid? row))
    '()
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'invalid-memory-durable-job
      'memory-job-rows
      'error
      (list (cons 'job-id
                  (agentic-ai-lab-durable-recovery-alist-ref
                   row
                   'job-id
                   #f))
            (cons 'diagnostics
                  (agentic-ai-lab-durable-recovery-alist-ref
                   row
                   'diagnostics
                   '()))
            (cons 'recoverable? #t))))))

;; : (-> [Alist] [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics/rev
      memory-job-rows
      diagnostics-rev)
  (if (null? memory-job-rows)
    diagnostics-rev
    (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics/rev
     (cdr memory-job-rows)
     (agentic-ai-lab-durable-recovery-reverse-onto
      (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics/one
       (car memory-job-rows))
      diagnostics-rev))))

;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics memory-job-rows)
  (if (list? memory-job-rows)
    (reverse
     (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics/rev
      memory-job-rows
      '()))
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'invalid-memory-job-rows
      'memory-job-rows
      'error
      (list (cons 'value memory-job-rows)
            (cons 'recoverable? #t))))))

;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-memory-job-diagnostics memory-job-rows)
  (if (null? memory-job-rows)
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'missing-memory-durable-job
      'memory-job-rows
      'error
      (list (cons 'recoverable? #t))))
    (agentic-ai-lab-durable-recovery-memory-job-row-diagnostics memory-job-rows)))

;; : (-> Alist [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-communication-diagnostics
      runtime-store-row
      communication-rows)
  (if (and (pair? communication-rows)
           (not (agentic-ai-lab-durable-recovery-runtime-store-ref
                 runtime-store-row
                 'communication-ledger-ref)))
    (list
     (agentic-ai-lab-durable-recovery-diagnostic
      'missing-communication-ledger-ref
      'communication-rows
      'error
      (list (cons 'communication-count (length communication-rows))
            (cons 'recoverable? #t))))
    '()))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-durable-recovery-missing-refs refs declared-refs)
  (cond
   ((null? refs) '())
   ((agentic-ai-lab-durable-recovery-member? (car refs) declared-refs)
    (agentic-ai-lab-durable-recovery-missing-refs (cdr refs) declared-refs))
   (else
    (cons (car refs)
          (agentic-ai-lab-durable-recovery-missing-refs (cdr refs)
                                                  declared-refs)))))

;; : (-> [Alist] [Symbol] [Alist])
(def (agentic-ai-lab-durable-recovery-sandbox-diagnostics workflow-task-rows
                                                     sandbox-refs)
  (if (list? workflow-task-rows)
    (reverse
     (agentic-ai-lab-durable-recovery-sandbox-diagnostics/rev
      workflow-task-rows
      sandbox-refs
      '()))
    '()))

;; : (-> [Alist] [Symbol] [Alist] [Alist])
(def (agentic-ai-lab-durable-recovery-sandbox-diagnostics/rev workflow-task-rows
                                                         sandbox-refs
                                                         diagnostics-rev)
  (if (null? workflow-task-rows)
    diagnostics-rev
    (let* ((task-row (car workflow-task-rows))
           (task-refs
            (agentic-ai-lab-durable-recovery-alist-ref
             task-row
             'sandbox-refs
             '()))
           (missing-refs
            (agentic-ai-lab-durable-recovery-missing-refs task-refs sandbox-refs)))
      (agentic-ai-lab-durable-recovery-sandbox-diagnostics/rev
       (cdr workflow-task-rows)
       sandbox-refs
       (if (null? missing-refs)
         diagnostics-rev
         (cons (agentic-ai-lab-durable-recovery-diagnostic
                'unresolved-sandbox-ref
                'sandbox-refs
                'error
                (list (cons 'task
                            (agentic-ai-lab-durable-recovery-alist-ref
                             task-row
                             'durable-task-id
                             #f))
                      (cons 'missing-refs missing-refs)
                      (cons 'recoverable? #t)))
               diagnostics-rev))))))

;;; Boundary: recovery diagnostics consolidate durable runtime, communication,
;;; memory, workflow, and sandbox evidence without executing recovery actions.
;; : (-> Symbol Symbol Symbol Symbol Alist [Alist] [Alist] [Alist] [Alist] [Symbol] [Alist])
(def (agentic-ai-lab-durable-recovery-diagnostics scenario-id
                                             project-id
                                             root-session-id
                                             session-id
                                             runtime-store-row
                                             communication-rows
                                             memory-job-rows
                                             workflow-task-rows
                                             sandbox-refs)
  (let* ((diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-required-symbol-diagnostics
            'missing-scenario-id
            'scenario-id
            scenario-id)
           '()))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-required-symbol-diagnostics
            'missing-project-id
            'project-id
            project-id)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-required-symbol-diagnostics
            'missing-root-session-id
            'root-session-id
            root-session-id)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-required-symbol-diagnostics
            'missing-session-id
            'session-id
            session-id)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-runtime-store-diagnostics
            runtime-store-row)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-communication-diagnostics
            runtime-store-row
            communication-rows)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-memory-job-diagnostics memory-job-rows)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-workflow-task-diagnostics
            workflow-task-rows)
           diagnostics-rev))
         (diagnostics-rev
          (agentic-ai-lab-durable-recovery-reverse-onto
           (agentic-ai-lab-durable-recovery-sandbox-diagnostics workflow-task-rows
                                                         sandbox-refs)
           diagnostics-rev)))
    (reverse diagnostics-rev)))

;; : (-> Symbol Symbol Symbol Symbol Alist [Alist] [Alist] [Alist] [Alist] [Symbol] [Alist])
(def (agentic-ai-lab-durable-recovery-observability-row scenario-id
                                                  stage
                                                  status
                                                  detail
                                                  runtime-owner
                                                  handoff-required
                                                  runtime-executed)
  (list
   (cons 'kind 'agentic-ai-lab.durable.recovery-observability-row)
   (cons 'schema +agentic-ai-lab-durable-recovery-observability-schema+)
   (cons 'scenario-id scenario-id)
   (cons 'stage stage)
   (cons 'status status)
   (cons 'detail detail)
   (cons 'runtime-owner runtime-owner)
   (cons 'handoff-required handoff-required)
   (cons 'runtime-executed runtime-executed)))

;; : (forall (a) (-> Symbol Symbol [a] String [a]))
;; : (-> Symbol Symbol [Alist] String [Alist])
(def (agentic-ai-lab-durable-recovery-observability-rows scenario-id
                                                   status
                                                   detail
                                                   runtime-owner)
  (map (lambda (stage)
         (agentic-ai-lab-durable-recovery-observability-row
          scenario-id
          stage
          status
          detail
          runtime-owner
          #t
          #f))
       +agentic-ai-lab-durable-recovery-stages+))
