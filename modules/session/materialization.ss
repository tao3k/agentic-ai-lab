;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime materialization receipts for session handoff.
;;; Invariant: receipts describe runtime state and handoff identity only;
;;; Scheme never waits on runtime futures, opens sandbox handles, or replays IO.

(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/receipt-syntax)

(export +agentic-ai-lab-session-materialization-states+
        agentic-ai-lab-session-materialization-state?
        make-agentic-ai-lab-session-materialization-receipt
        agentic-ai-lab-session-materialization-receipt?
        agentic-ai-lab-session-materialization-receipt-request-id
        agentic-ai-lab-session-materialization-receipt-project-id
        agentic-ai-lab-session-materialization-receipt-root-session-ref
        agentic-ai-lab-session-materialization-receipt-session-ref
        agentic-ai-lab-session-materialization-receipt-parent-session-refs
        agentic-ai-lab-session-materialization-receipt-state
        agentic-ai-lab-session-materialization-receipt-pending-runtime-ref
        agentic-ai-lab-session-materialization-receipt-sandbox-handle-ref
        agentic-ai-lab-session-materialization-receipt-token-usage-summary
        agentic-ai-lab-session-materialization-receipt-error-summary
        agentic-ai-lab-session-materialization-receipt-declaration-checked?
        agentic-ai-lab-session-materialization-receipt-declared-session-refs
        agentic-ai-lab-session-materialization-receipt-declared-parent-session-refs
        agentic-ai-lab-session-materialization-receipt-declared-sandbox-handle-refs
        agentic-ai-lab-session-materialization-receipt-root-session-declared?
        agentic-ai-lab-session-materialization-receipt-session-declared?
        agentic-ai-lab-session-materialization-receipt-undeclared-session-refs
        agentic-ai-lab-session-materialization-receipt-undeclared-parent-session-refs
        agentic-ai-lab-session-materialization-receipt-sandbox-handle-declared?
        agentic-ai-lab-session-materialization-receipt-valid?
        agentic-ai-lab-session-materialization-receipt-diagnostic-count
        agentic-ai-lab-session-materialization-receipt-diagnostics
        agentic-ai-lab-session-materialization-receipt-runtime-owner
        agentic-ai-lab-session-materialization-receipt-runtime-executed?
        agentic-ai-lab-session-runtime-materialization-receipt
        agentic-ai-lab-session-materialization-receipt->alist)

;; : [Symbol]
(def +agentic-ai-lab-session-materialization-states+
  '(pending materialized failed dropped))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-session-materialization-state? value)
  (and (symbol? value)
       (if (member value +agentic-ai-lab-session-materialization-states+)
         #t
         #f)))

;; : (-> Alist Symbol Object)
(def (agentic-ai-lab-session-materialization-metadata-ref metadata key)
  (agentic-ai-lab-session-alist-ref metadata key #f))

;; : (-> [Alist] Alist)
(def (agentic-ai-lab-session-materialization-request-metadata maybe-metadata)
  (if (null? maybe-metadata) '() (car maybe-metadata)))

;; : (-> Object Object Object)
(def (agentic-ai-lab-session-materialization-selected-refs refs fallback)
  (if refs refs fallback))

;; : (-> Object [Object])
(def (agentic-ai-lab-session-materialization-required-refs refs)
  (if refs refs '()))

;; : (-> Object Boolean)
(def (agentic-ai-lab-session-materialization-declaration-checked? refs)
  (if refs #t #f))

;; : (-> Object Boolean)
(def (agentic-ai-lab-session-materialization-maybe-symbol-list? value)
  (or (not value)
      (agentic-ai-lab-session-every? symbol? value)))

;; : (-> Symbol [Symbol] Boolean)
(def (agentic-ai-lab-session-materialization-member? value declared-refs)
  (if (member value declared-refs) #t #f))

;; : (-> Alist Alist Alist)
(def (agentic-ai-lab-session-materialization-rows/tail rows tail)
  (foldr cons tail rows))

;;; Boundary: materialization callers construct explicit receipt field pairs.
;; : (-> (List (Pair Symbol Object)) (List (Pair Symbol Object)))
(def (agentic-ai-lab-session-materialization-field-rows . rows)
  rows)

;; : (-> [Symbol] Object [Symbol])
(def (agentic-ai-lab-session-materialization-undeclared-refs refs declared-refs)
  (if declared-refs
    (filter
     (lambda (ref)
       (not (agentic-ai-lab-session-materialization-member? ref declared-refs)))
     refs)
    '()))

;; : (-> Symbol Symbol Object Alist)
(def (agentic-ai-lab-session-materialization-diagnostic code request-id detail)
  (agentic-ai-lab-session-materialization-field-rows
   (cons 'kind 'agentic-ai-lab.session.materialization.diagnostic)
   (cons 'schema 'agentic-ai-lab.modules.session.materialization.diagnostic.v1)
   (cons 'code code)
   (cons 'request-id request-id)
   (cons 'detail detail)
   (cons 'severity 'error)
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol [Symbol] [Alist] [Alist])
(def (agentic-ai-lab-session-materialization-session-diagnostics/rev request-id
                                                               code
                                                               session-refs
                                                               diagnostics-rev)
  (if (null? session-refs)
    diagnostics-rev
    (agentic-ai-lab-session-materialization-session-diagnostics/rev
     request-id
     code
     (cdr session-refs)
     (cons (agentic-ai-lab-session-materialization-diagnostic
            code
            request-id
            (agentic-ai-lab-session-materialization-field-rows
             (cons 'session-ref (car session-refs))))
           diagnostics-rev))))

;; : (-> Symbol Symbol [Symbol] [Alist])
(def (agentic-ai-lab-session-materialization-session-diagnostics request-id
                                                           code
                                                           session-refs)
  (reverse
   (agentic-ai-lab-session-materialization-session-diagnostics/rev
    request-id
    code
    session-refs
    '())))

;; : (-> Symbol Symbol Object [Alist])
(def (agentic-ai-lab-session-materialization-sandbox-diagnostics request-id
                                                           sandbox-handle-ref
                                                           declared-refs)
  (if (and declared-refs
           sandbox-handle-ref
           (not (agentic-ai-lab-session-materialization-member?
                 sandbox-handle-ref
                 declared-refs)))
    (list
     (agentic-ai-lab-session-materialization-diagnostic
      'materialization-sandbox-handle-not-declared
      request-id
      (agentic-ai-lab-session-materialization-field-rows
       (cons 'sandbox-handle-ref sandbox-handle-ref))))
    '()))

;; : (-> Symbol Symbol Object Object [Alist])
(def (agentic-ai-lab-session-materialization-state-diagnostics request-id
                                                         state
                                                         sandbox-handle-ref
                                                         error-summary)
  (agentic-ai-lab-session-materialization-rows/tail
   (if (and (or (eq? state 'pending)
                (eq? state 'materialized))
            (not sandbox-handle-ref))
     (list
      (agentic-ai-lab-session-materialization-diagnostic
       'materialization-sandbox-handle-required
       request-id
       (agentic-ai-lab-session-materialization-field-rows
        (cons 'state state))))
     '())
   (if (and (eq? state 'failed)
            (not error-summary))
     (list
      (agentic-ai-lab-session-materialization-diagnostic
       'materialization-failed-missing-error-summary
       request-id
       '()))
     '())))

;; : (-> RequestId ProjectId RootSessionRef SessionRef ParentSessionRefs State PendingRuntimeRef SandboxHandleRef TokenUsageSummary ErrorSummary RuntimeOwner RuntimeExecuted Metadata PooSessionMaterializationReceipt)
(defstruct agentic-ai-lab-session-materialization-receipt
  (request-id
   project-id
   root-session-ref
   session-ref
   parent-session-refs
   state
   pending-runtime-ref
   sandbox-handle-ref
   token-usage-summary
   error-summary
   declaration-checked?
   declared-session-refs
   declared-parent-session-refs
   declared-sandbox-handle-refs
   root-session-declared?
   session-declared?
   undeclared-session-refs
   undeclared-parent-session-refs
   sandbox-handle-declared?
   valid?
   diagnostic-count
   diagnostics
   runtime-owner
   runtime-executed?
   metadata)
  transparent: #t)

;;; Boundary: runtime materialization receipts bind checkpoint ids, runtime
;;; owner, and session metadata without executing durable runtime work.
;; : (-> Symbol Symbol Symbol Symbol [Symbol] Symbol Symbol MaybeSymbol Alist MaybeAlist [Alist] PooSessionMaterializationReceipt)
(def (agentic-ai-lab-session-runtime-materialization-receipt request-id
                                                       project-id
                                                       root-session-ref
                                                       session-ref
                                                       parent-session-refs
                                                       state
                                                       pending-runtime-ref
                                                       sandbox-handle-ref
                                                       token-usage-summary
                                                       error-summary
                                                       . maybe-metadata)
  (agentic-ai-lab-session-require "session materialization request id must be a symbol"
                            (symbol? request-id)
                            request-id)
  (agentic-ai-lab-session-require "session materialization project id must be a symbol"
                            (symbol? project-id)
                            project-id)
  (agentic-ai-lab-session-require "session materialization root ref must be a symbol"
                            (symbol? root-session-ref)
                            root-session-ref)
  (agentic-ai-lab-session-require "session materialization session ref must be a symbol"
                            (symbol? session-ref)
                            session-ref)
  (agentic-ai-lab-session-require
   "session materialization parent refs must be symbols"
   (agentic-ai-lab-session-every? symbol? parent-session-refs)
   parent-session-refs)
  (agentic-ai-lab-session-require
   "session materialization state must be pending, materialized, failed, or dropped"
   (agentic-ai-lab-session-materialization-state? state)
   state)
  (agentic-ai-lab-session-require
   "session materialization pending runtime ref must be a symbol"
   (symbol? pending-runtime-ref)
   pending-runtime-ref)
  (agentic-ai-lab-session-require
   "session materialization sandbox handle ref must be a symbol or #f"
   (or (symbol? sandbox-handle-ref) (not sandbox-handle-ref))
   sandbox-handle-ref)
  (agentic-ai-lab-session-require
   "session materialization token usage summary must be an alist"
   (list? token-usage-summary)
   token-usage-summary)
  (agentic-ai-lab-session-require
   "session materialization error summary must be an alist or #f"
   (or (list? error-summary) (not error-summary))
   error-summary)
  (let* ((metadata
          (agentic-ai-lab-session-materialization-request-metadata maybe-metadata))
         (declared-session-refs
          (agentic-ai-lab-session-materialization-metadata-ref
           metadata
           'declared-session-refs))
         (declared-parent-session-refs0
          (agentic-ai-lab-session-materialization-metadata-ref
           metadata
           'declared-parent-session-refs))
         (declared-parent-session-refs
          (agentic-ai-lab-session-materialization-selected-refs
           declared-parent-session-refs0
           declared-session-refs))
         (declared-sandbox-handle-refs
          (agentic-ai-lab-session-materialization-metadata-ref
           metadata
           'declared-sandbox-handle-refs)))
    (agentic-ai-lab-session-require
     "session materialization declared session refs must be symbols"
     (agentic-ai-lab-session-materialization-maybe-symbol-list?
      declared-session-refs)
     declared-session-refs)
    (agentic-ai-lab-session-require
     "session materialization declared parent refs must be symbols"
     (agentic-ai-lab-session-materialization-maybe-symbol-list?
      declared-parent-session-refs)
     declared-parent-session-refs)
    (agentic-ai-lab-session-require
     "session materialization declared sandbox handle refs must be symbols"
     (agentic-ai-lab-session-materialization-maybe-symbol-list?
      declared-sandbox-handle-refs)
     declared-sandbox-handle-refs)
    (let* ((declaration-checked?
            (agentic-ai-lab-session-materialization-declaration-checked?
             declared-session-refs))
           (root-session-declared?
            (or (not declared-session-refs)
                (agentic-ai-lab-session-materialization-member?
                 root-session-ref
                 declared-session-refs)))
           (session-declared?
            (or (not declared-session-refs)
                (agentic-ai-lab-session-materialization-member?
                 session-ref
                 declared-session-refs)))
           (undeclared-session-refs
            (agentic-ai-lab-session-materialization-undeclared-refs
             (list root-session-ref session-ref)
             declared-session-refs))
           (undeclared-parent-session-refs
            (agentic-ai-lab-session-materialization-undeclared-refs
             parent-session-refs
             declared-parent-session-refs))
           (sandbox-handle-declared?
            (or (not declared-sandbox-handle-refs)
                (not sandbox-handle-ref)
                (agentic-ai-lab-session-materialization-member?
                 sandbox-handle-ref
                 declared-sandbox-handle-refs)))
           (diagnostics
            (agentic-ai-lab-session-materialization-rows/tail
             (agentic-ai-lab-session-materialization-session-diagnostics
              request-id
              'materialization-session-not-declared
              undeclared-session-refs)
             (agentic-ai-lab-session-materialization-rows/tail
              (agentic-ai-lab-session-materialization-session-diagnostics
               request-id
               'materialization-parent-session-not-declared
               undeclared-parent-session-refs)
              (agentic-ai-lab-session-materialization-rows/tail
               (agentic-ai-lab-session-materialization-sandbox-diagnostics
                request-id
                sandbox-handle-ref
                declared-sandbox-handle-refs)
               (agentic-ai-lab-session-materialization-state-diagnostics
                request-id
                state
                sandbox-handle-ref
                error-summary))))))
      (make-agentic-ai-lab-session-materialization-receipt
       request-id
       project-id
       root-session-ref
       session-ref
       parent-session-refs
       state
       pending-runtime-ref
       sandbox-handle-ref
       token-usage-summary
       error-summary
       declaration-checked?
       (agentic-ai-lab-session-materialization-required-refs declared-session-refs)
       (agentic-ai-lab-session-materialization-required-refs
        declared-parent-session-refs)
       (agentic-ai-lab-session-materialization-required-refs
        declared-sandbox-handle-refs)
       root-session-declared?
       session-declared?
       undeclared-session-refs
       undeclared-parent-session-refs
       sandbox-handle-declared?
       (null? diagnostics)
       (length diagnostics)
       diagnostics
       "marlin-agent-core"
       #f
       metadata))))

;; : (-> PooSessionMaterializationReceipt Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-materialization-receipt->alist
  (receipt)
  (require agentic-ai-lab-session-require
           "session materialization projection requires a receipt"
           (agentic-ai-lab-session-materialization-receipt? receipt)
           receipt)
  (bindings ())
  (fields
   (('kind 'agentic-ai-lab.session.materialization-receipt)
    ('schema 'agentic-ai-lab.modules.session.materialization-receipt.v1)
    ('request-id
     (agentic-ai-lab-session-materialization-receipt-request-id receipt))
    ('project-id
     (agentic-ai-lab-session-materialization-receipt-project-id receipt))
    ('root-session-ref
     (agentic-ai-lab-session-materialization-receipt-root-session-ref receipt))
    ('session-ref
     (agentic-ai-lab-session-materialization-receipt-session-ref receipt))
    ('parent-session-refs
     (agentic-ai-lab-session-materialization-receipt-parent-session-refs
      receipt))
    ('materialization-state
     (agentic-ai-lab-session-materialization-receipt-state receipt))
    ('pending-runtime-ref
     (agentic-ai-lab-session-materialization-receipt-pending-runtime-ref
      receipt))
    ('sandbox-handle-ref
     (agentic-ai-lab-session-materialization-receipt-sandbox-handle-ref
      receipt))
    ('token-usage-summary
     (agentic-ai-lab-session-materialization-receipt-token-usage-summary
      receipt))
    ('error-summary
     (agentic-ai-lab-session-materialization-receipt-error-summary receipt))
    ('declaration-checked?
     (agentic-ai-lab-session-materialization-receipt-declaration-checked?
      receipt))
    ('declared-session-refs
     (agentic-ai-lab-session-materialization-receipt-declared-session-refs
      receipt))
    ('declared-parent-session-refs
     (agentic-ai-lab-session-materialization-receipt-declared-parent-session-refs
      receipt))
    ('declared-sandbox-handle-refs
     (agentic-ai-lab-session-materialization-receipt-declared-sandbox-handle-refs
      receipt))
    ('root-session-declared?
     (agentic-ai-lab-session-materialization-receipt-root-session-declared?
      receipt))
    ('session-declared?
     (agentic-ai-lab-session-materialization-receipt-session-declared?
      receipt))
    ('undeclared-session-refs
     (agentic-ai-lab-session-materialization-receipt-undeclared-session-refs
      receipt))
    ('undeclared-parent-session-refs
     (agentic-ai-lab-session-materialization-receipt-undeclared-parent-session-refs
      receipt))
    ('sandbox-handle-declared?
     (agentic-ai-lab-session-materialization-receipt-sandbox-handle-declared?
      receipt))
    ('valid?
     (agentic-ai-lab-session-materialization-receipt-valid? receipt))
    ('diagnostic-count
     (agentic-ai-lab-session-materialization-receipt-diagnostic-count receipt))
    ('diagnostics
     (agentic-ai-lab-session-materialization-receipt-diagnostics receipt))
    ('runtime-owner
     (agentic-ai-lab-session-materialization-receipt-runtime-owner receipt))
    ('runtime-executed
     (agentic-ai-lab-session-materialization-receipt-runtime-executed?
      receipt))
    ('handoff-required #t)
    ('metadata
     (agentic-ai-lab-session-materialization-receipt-metadata receipt)))))
