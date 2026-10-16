;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: receipts record observed execution outcomes.
;;; Invariant: retry, scheduling, and adapter policy remain outside receipts.

(import :poo-flow/modules/workflow/control-plane/projection-syntax)

(export make-receipt
        receipt?
        receipt-flow
        receipt-task
        receipt-kind
        receipt-node-id
        receipt-strategy
        receipt-policy
        receipt-adapter-decision
        receipt-request-id
        receipt-input
        receipt-output
        receipt-cache
        receipt-frontier
        receipt-status
        receipt-error
        receipt-children
        receipt->audit-events
        receipt->run-summary
        receipt-event-count
        receipt-adapter-request-count
        receipt-ok?
        receipt-failed?)

;;; Children preserve nested execution evidence without forcing a runner to
;;; flatten or discard subflow receipts.
;;; Frontier evidence records which plan node ids were ready before the
;;; observed execution point, keeping scheduler policy inspectable after a run.
;;; Node identity is captured separately from task identity so replay policy can
;;; detect ordering drift even when task names repeat.
;;; Policy records the adapter-stable strategy snapshot that produced the
;;; frontier, cache mode, and failure behavior for this observation.
;; : (-> Flow Task Symbol NodeId Strategy Policy AdapterDecision RequestId Value Value Cache [Id] Symbol Error [Receipt] Receipt)
(defstruct receipt
  (flow
   task
   kind
   node-id
   strategy
   policy
   adapter-decision
   request-id
   input
   output
   cache
   frontier
   status
   error
   children)
  transparent: #t)

;; : (-> Receipt Boolean)
(def (receipt-ok? receipt)
  (eq? (receipt-status receipt) 'ok))

;; : (-> Receipt Boolean)
(def (receipt-failed? receipt)
  (eq? (receipt-status receipt) 'failed))

;;; Intent: flatten nested receipt trees into a replay-friendly event stream
;;; while preserving child order with a stable path.
;;; Each event omits raw input/output values so external persistence can store
;;; control-plane evidence without capturing potentially large runtime payloads.
;; : (-> Receipt [AuditEvent])
(def (receipt->audit-events receipt)
  (receipt->audit-events-at receipt '()))

;;; A run summary keeps root status and aggregate counts next to the event log.
;;; This is the durable handoff shape for Rust or external storage layers that
;;; want audit evidence before they implement full replay execution.
;; : (-> Receipt [AuditEvent] Nat Nat RunSummary)
(defpoo-core-receipt-projection
  receipt-run-summary (receipt events event-count adapter-request-count)
  (bindings ())
  (fields ((flow (receipt-flow receipt))
           (kind (receipt-kind receipt))
           (status (receipt-status receipt))
           (strategy (receipt-strategy receipt))
           (policy (receipt-policy receipt))
           (frontier (receipt-frontier receipt))
           (event-count event-count)
           (adapter-request-count adapter-request-count)
           (events events))))

;; : (-> Receipt RunSummary)
(def (receipt->run-summary receipt)
  (let-values (((events event-count adapter-request-count)
                (receipt-audit-summary receipt)))
    (receipt-run-summary receipt events event-count adapter-request-count)))

;;; Event count is tree cardinality, not step count; the root receipt is counted
;;; because it carries run-level frontier and status evidence.
;; : (-> Receipt Nat)
(def (receipt-event-count receipt)
  (+ 1 (receipt-list-event-count (receipt-children receipt))))

;;; Adapter request count follows request-id evidence on receipts instead of
;;; task kind names, keeping the summary tied to observed adapter decisions.
;; : (-> Receipt Nat)
(def (receipt-adapter-request-count receipt)
  (+ (if (receipt-request-id receipt) 1 0)
     (receipt-list-adapter-request-count (receipt-children receipt))))

;;; Path construction is separated from event shape so nested subflow receipts
;;; can be replayed without flattening away hierarchy.
;; : (-> Receipt [Nat] [AuditEvent])
(def (receipt->audit-events-at receipt path)
  (let-values (((events _event-count _adapter-request-count)
                (receipt-audit-summary-at receipt path '() 0 0)))
    (reverse events)))

;;; Audit events are intentionally small alists: they describe control-plane
;;; decisions, not application payloads.
;; : (-> Receipt [Nat] AuditEvent)
(defpoo-core-receipt-projection
  receipt->audit-event (receipt path)
  (bindings ())
  (fields ((path path)
           (flow (receipt-flow receipt))
           (task (receipt-task receipt))
           (kind (receipt-kind receipt))
           (node-id (receipt-node-id receipt))
           (strategy (receipt-strategy receipt))
           (policy (receipt-policy receipt))
           (adapter-decision (receipt-adapter-decision receipt))
           (request-id (receipt-request-id receipt))
           (cache (receipt-cache receipt))
           (frontier (receipt-frontier receipt))
           (status (receipt-status receipt))
           (error (receipt-error receipt))
           (child-count (length (receipt-children receipt))))))

;;; Intent: recursively collect child event streams in child ordinal order.
;;; The ordinal path is the replay cursor; it remains stable even if task names
;;; repeat inside nested flows.
;; : (forall (a) (-> [a] [a] [a]))
(def (receipt-values/tail values tail)
  (append values tail))

;; : (-> Receipt (Values [AuditEvent] Nat Nat))
(def (receipt-audit-summary receipt)
  (let-values (((events event-count adapter-request-count)
                (receipt-audit-summary-at receipt '() '() 0 0)))
    (values (reverse events) event-count adapter-request-count)))

;; : (-> Receipt [Nat] [AuditEvent] Nat Nat (Values [AuditEvent] Nat Nat))
(def (receipt-audit-summary-at receipt path events event-count adapter-request-count)
  (receipt-children-audit-summary
   (receipt-children receipt)
   path
   0
   (cons (receipt->audit-event receipt path) events)
   (+ event-count 1)
   (+ adapter-request-count
      (if (receipt-request-id receipt) 1 0))))

;; : (-> [Receipt] [Nat] Nat [AuditEvent] Nat Nat (Values [AuditEvent] Nat Nat))
(def (receipt-children-audit-summary children parent-path ordinal events event-count adapter-request-count)
  (if (null? children)
    (values events event-count adapter-request-count)
    (let-values (((child-events child-event-count child-adapter-request-count)
                  (receipt-audit-summary-at
                   (car children)
                   (receipt-values/tail parent-path (list ordinal))
                   events
                   event-count
                   adapter-request-count)))
      (receipt-children-audit-summary (cdr children)
                                      parent-path
                                      (+ ordinal 1)
                                      child-events
                                      child-event-count
                                      child-adapter-request-count))))

;;; Boundary: receipt list event count is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Receipt] Nat)
(def (receipt-list-event-count receipts)
  (if (null? receipts)
    0
    (+ (receipt-event-count (car receipts))
       (receipt-list-event-count (cdr receipts)))))

;;; Boundary: receipt list adapter request count is the policy-visible edge for
;;; core behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Receipt] Nat)
(def (receipt-list-adapter-request-count receipts)
  (if (null? receipts)
    0
    (+ (receipt-adapter-request-count (car receipts))
       (receipt-list-adapter-request-count (cdr receipts)))))
