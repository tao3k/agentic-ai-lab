;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bridge durable rows into runtime-store operation receipts.
;;; Invariant: this is a functional projection layer only; Scheme does not
;;; append logs, claim leases, retain artifacts, or attach sandbox handles.

(import :poo-flow/modules/ai-agentic-context/features/memory/durable/store-operation
        :core/utilities/final-projection-syntax)

(export poo-flow-durable-runtime-store-operations-from-rows
        poo-flow-durable-runtime-store-rows->marlin-handoff)

;; : (-> Alist Symbol Object Object)
(def (bridge-ref row key default-value)
  (if (list? row)
    (let (entry (assoc key row))
      (if entry (cdr entry) default-value))
    default-value))

;; : (-> Object [Symbol] [Symbol])
(def (bridge-symbols/rev value symbols-rev)
  (cond
   ((symbol? value) (cons value symbols-rev))
   ((pair? value)
    (bridge-symbols/rev
     (cdr value)
     (bridge-symbols/rev (car value) symbols-rev)))
   (else symbols-rev)))

;; : (-> Object [Symbol])
(def (bridge-symbols value)
  (reverse (bridge-symbols/rev value '())))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (bridge-unique symbols seen)
  (cond
   ((null? symbols) '())
   ((member (car symbols) seen)
    (bridge-unique (cdr symbols) seen))
   (else
    (cons (car symbols)
          (bridge-unique (cdr symbols)
                         (cons (car symbols) seen))))))

;; : (-> Object [Symbol])
(def (bridge-symbol-refs value)
  (bridge-unique (bridge-symbols value) '()))

;; : (-> Object [Symbol] Alist)
(def (bridge-options target-ref causal-refs)
  (if target-ref
    (poo-flow-product-field-rows
     (target-ref target-ref)
     (causal-refs (bridge-symbol-refs causal-refs)))
    (poo-flow-product-field-rows
     (causal-refs (bridge-symbol-refs causal-refs)))))

;; : (-> Alist Symbol Symbol Symbol Alist Object [Symbol] Object)
(def (bridge-operation negotiation
                       operation-id
                       operation-kind
                       source-kind
                       row
                       target-ref
                       causal-refs)
  (poo-flow-durable-runtime-store-operation
   operation-id
   operation-kind
   negotiation
   (poo-flow-product-field-rows
    (source-kind source-kind)
    (source-row row))
   (bridge-options target-ref causal-refs)))

;; : (-> Alist Alist Object)
(def (bridge-session-graph-operation negotiation row)
  (and row
       (bridge-operation
        negotiation
        (bridge-ref row 'root-session-ref
                    (bridge-ref row 'project-id 'session-graph))
        'append-fact
        'session-graph
        row
        #f
        (list (bridge-ref row 'root-session-ref #f)
              (bridge-ref row 'session-ids '())))))

;; : (-> Alist Alist Object)
(def (bridge-communication-operation negotiation row)
  (bridge-operation
   negotiation
   (bridge-ref row 'channel-id 'communication-event)
   'append-communication-event
   'session-communication
   row
   (bridge-ref row 'communication-ledger-ref #f)
   (list (bridge-ref row 'source-session-id #f)
         (bridge-ref row 'target-session-id #f)
         (bridge-ref row 'channel-id #f))))

;; : (-> Alist Alist Object)
(def (bridge-memory-job-operation negotiation row)
  (bridge-operation
   negotiation
   (bridge-ref row 'job-id 'memory-job)
   'claim-job-lease
   'memory-durable-job
   row
   (bridge-ref row 'job-store-ref #f)
   (list (bridge-ref row 'job-id #f)
         (bridge-ref row 'session-id #f)
         (bridge-ref row 'source-ref #f))))

;; : (-> Alist Alist Object)
(def (bridge-workflow-task-operation negotiation row)
  (bridge-operation
   negotiation
   (bridge-ref row 'durable-task-id
               (bridge-ref row 'check 'workflow-task))
   'append-fact
   'workflow-task
   row
   #f
   (list (bridge-ref row 'durable-task-id #f)
         (bridge-ref row 'checkpoint-ref #f)
         (bridge-ref row 'sandbox-refs '()))))

;; : (-> Alist Symbol Object)
(def (bridge-artifact-operation negotiation artifact-ref)
  (bridge-operation
   negotiation
   artifact-ref
   'retain-artifact
   'workflow-artifact
   (poo-flow-product-field-rows
    (artifact-ref artifact-ref))
   #f
   (list artifact-ref)))

;; : (-> Alist Symbol Object)
(def (bridge-sandbox-operation negotiation sandbox-ref)
  (bridge-operation
   negotiation
   sandbox-ref
   'attach-sandbox-handle
   'sandbox-handle
   (poo-flow-product-field-rows
    (sandbox-ref sandbox-ref))
   #f
   (list sandbox-ref)))

;; : (-> [Object] [Object] [Object])
(def (bridge-reverse-onto values tail)
  (if (null? values)
    tail
    (bridge-reverse-onto (cdr values) (cons (car values) tail))))

;; : (-> [Alist] Symbol [Symbol] [Symbol])
(def (bridge-row-symbol-refs/rev rows key refs-rev)
  (if (pair? rows)
    (bridge-row-symbol-refs/rev
     (cdr rows)
     key
     (bridge-reverse-onto
      (bridge-symbol-refs (bridge-ref (car rows) key '()))
      refs-rev))
    refs-rev))

;; : (-> [Alist] Symbol [Symbol])
(def (bridge-row-symbol-refs rows key)
  (reverse (bridge-row-symbol-refs/rev rows key '())))

;; : (-> Alist [Alist] [Object] [Object])
(def (bridge-communication-operations/rev negotiation rows operations-rev)
  (if (null? rows)
    operations-rev
    (bridge-communication-operations/rev
     negotiation
     (cdr rows)
     (cons (bridge-communication-operation negotiation (car rows))
           operations-rev))))

;; : (-> Alist [Alist] [Object] [Object])
(def (bridge-memory-job-operations/rev negotiation rows operations-rev)
  (if (null? rows)
    operations-rev
    (bridge-memory-job-operations/rev
     negotiation
     (cdr rows)
     (cons (bridge-memory-job-operation negotiation (car rows))
           operations-rev))))

;; : (-> Alist [Alist] [Object] [Object])
(def (bridge-workflow-task-operations/rev negotiation rows operations-rev)
  (if (null? rows)
    operations-rev
    (bridge-workflow-task-operations/rev
     negotiation
     (cdr rows)
     (cons (bridge-workflow-task-operation negotiation (car rows))
           operations-rev))))

;; : (-> Alist [Symbol] [Object] [Object])
(def (bridge-artifact-operations/rev negotiation artifact-refs operations-rev)
  (if (null? artifact-refs)
    operations-rev
    (bridge-artifact-operations/rev
     negotiation
     (cdr artifact-refs)
     (cons (bridge-artifact-operation negotiation (car artifact-refs))
           operations-rev))))

;; : (-> Alist [Symbol] [Object] [Object])
(def (bridge-sandbox-operations/rev negotiation sandbox-refs operations-rev)
  (if (null? sandbox-refs)
    operations-rev
    (bridge-sandbox-operations/rev
     negotiation
     (cdr sandbox-refs)
     (cons (bridge-sandbox-operation negotiation (car sandbox-refs))
           operations-rev))))

;; : (-> Object [Object] [Object])
(def (bridge-session-graph-operation/rev operation operations-rev)
  (if operation (cons operation operations-rev) operations-rev))

;; : (-> Alist Alist [Alist] [Alist] [Alist] [Symbol] [Object])
(def (poo-flow-durable-runtime-store-operations-from-rows negotiation
                                                          session-graph-row
                                                          communication-rows
                                                          memory-job-rows
                                                          workflow-task-rows
                                                          sandbox-refs)
  (let* ((session-graph-operation
          (bridge-session-graph-operation negotiation session-graph-row))
         (artifact-refs
          (bridge-unique (bridge-row-symbol-refs workflow-task-rows
                                                 'artifact-refs)
                         '()))
         (all-sandbox-refs
          (bridge-unique
           (append (bridge-symbol-refs sandbox-refs)
                   (bridge-row-symbol-refs workflow-task-rows 'sandbox-refs))
           '())))
    (reverse
     (bridge-sandbox-operations/rev
      negotiation
      all-sandbox-refs
      (bridge-artifact-operations/rev
       negotiation
       artifact-refs
       (bridge-workflow-task-operations/rev
        negotiation
        workflow-task-rows
        (bridge-memory-job-operations/rev
         negotiation
         memory-job-rows
         (bridge-communication-operations/rev
          negotiation
          communication-rows
          (bridge-session-graph-operation/rev session-graph-operation
                                             '())))))))))

;; : (-> Alist Alist [Alist] [Alist] [Alist] [Symbol] Alist)
(def (poo-flow-durable-runtime-store-rows->marlin-handoff negotiation
                                                          session-graph-row
                                                          communication-rows
                                                          memory-job-rows
                                                          workflow-task-rows
                                                          sandbox-refs)
  (poo-flow-durable-runtime-store-operations->marlin-handoff
   negotiation
   (poo-flow-durable-runtime-store-operations-from-rows
    negotiation
    session-graph-row
    communication-rows
    memory-job-rows
    workflow-task-rows
    sandbox-refs)))
