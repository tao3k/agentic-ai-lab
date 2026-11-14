;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine policy-extension receipt lowering.
;;; Invariant: slot validation is delegated to the policy-extension contract owner.

(import (only-in :clan/poo/object .ref .slot?)
        "policy-extension-contract.ss")

(export agentic-ai-lab-user-loop-engine-poo-policy-extensions->receipts)

;;; Boundary: user loop engine policy extension optional row is the policy-
;;; visible edge for module-system, loop behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> Symbol Value AgenticAILabPolicyExtensionReceiptRows)
(def (agentic-ai-lab-user-loop-engine-policy-extension-optional-row key value)
  (if value (list (cons key value)) '()))

;;; Boundary: user loop engine policy extension optional list row is the
;;; policy-visible edge for module-system, loop behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> Symbol Value AgenticAILabPolicyExtensionReceiptRows)
(def (agentic-ai-lab-user-loop-engine-policy-extension-optional-list-row key value)
  (if (null? value) '() (list (cons key value))))

;;; This slot table is the projection whitelist for all concrete policy
;;; extension families. Adding a new receipt field means adding it here and to
;;; the contract dispatch below.
;; : [Symbol]
(def +agentic-ai-lab-user-loop-engine-policy-extension-slots+
  '(priority
    state-files
    acting-on-key
    conflict-action
    branch-lock-scope
    human-inbox
    run-log
    run-log-schema
    budget-path
    metric-keys
    retention-window
    slow-signals
    pause-signals
    kill-signals
    denylist-paths
    allowlist-paths
    human-gates
    connector-scopes
    auto-merge
    max-attempts))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-user-loop-engine-policy-extension-list-slot? slot)
  (or (eq? slot 'priority)
      (eq? slot 'state-files)
      (eq? slot 'run-log-schema)
      (eq? slot 'metric-keys)
      (eq? slot 'slow-signals)
      (eq? slot 'pause-signals)
      (eq? slot 'kill-signals)
      (eq? slot 'denylist-paths)
      (eq? slot 'allowlist-paths)
      (eq? slot 'human-gates)
      (eq? slot 'connector-scopes)))

;;; Slot dispatch is grouped by contract family so concrete extensions can
;;; compose the same validator surface without duplicating per-family code.
;; : (-> AgenticAILabLoopEnginePolicyExtensionPrototype Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-policy-extension-slot
      policy-extension
      slot
      value)
  (cond
   ((or (eq? slot 'priority)
        (eq? slot 'metric-keys)
        (eq? slot 'slow-signals)
        (eq? slot 'pause-signals)
        (eq? slot 'kill-signals)
        (eq? slot 'human-gates)
        (eq? slot 'connector-scopes))
    (agentic-ai-lab-user-loop-engine-policy-extension-require-symbol-list-slot
     'loop-engine-policy-extension
     slot
     value))
   ((or (eq? slot 'state-files)
        (eq? slot 'run-log-schema))
    (agentic-ai-lab-user-loop-engine-policy-extension-require-alist-slot
     'loop-engine-policy-extension
     slot
     value))
   ((or (eq? slot 'denylist-paths)
        (eq? slot 'allowlist-paths))
    (agentic-ai-lab-user-loop-engine-policy-extension-require-string-list-slot
     'loop-engine-policy-extension
     slot
     value))
   ((or (eq? slot 'acting-on-key)
        (eq? slot 'conflict-action)
        (eq? slot 'branch-lock-scope)
        (eq? slot 'retention-window)
        (eq? slot 'auto-merge))
    (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-symbol-slot
     'loop-engine-policy-extension
     slot
     value))
   ((or (eq? slot 'human-inbox)
        (eq? slot 'run-log)
        (eq? slot 'budget-path))
    (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-string-slot
     'loop-engine-policy-extension
     slot
     value))
   ((eq? slot 'max-attempts)
    (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-integer-slot
     'loop-engine-policy-extension
     slot
     value))
   (else
    (error "unknown loop-engine policy-extension projection slot" slot))))

;;; Boundary: user loop engine policy extension slot to row is the policy-
;;; visible edge for module-system, loop behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> AgenticAILabLoopEnginePolicyExtensionPrototype Symbol AgenticAILabPolicyExtensionReceiptRows)
(def (agentic-ai-lab-user-loop-engine-policy-extension-slot->row
      policy-extension
      slot)
  (if (.slot? policy-extension slot)
    (let (value (.ref policy-extension slot))
      (agentic-ai-lab-user-loop-engine-require-policy-extension-slot
       policy-extension
       slot
       value)
      (if (agentic-ai-lab-user-loop-engine-policy-extension-list-slot? slot)
        (agentic-ai-lab-user-loop-engine-policy-extension-optional-list-row
         slot
         value)
        (agentic-ai-lab-user-loop-engine-policy-extension-optional-row
         slot
         value)))
    '()))

;;; Boundary: user loop engine policy extension slots to rows is the policy-
;;; visible edge for module-system, loop behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> AgenticAILabLoopEnginePolicyExtensionPrototype [Symbol] AgenticAILabPolicyExtensionReceiptRows)
(def (agentic-ai-lab-user-loop-engine-policy-extension-slots->rows
      policy-extension
      slots)
  (cond
   ((null? slots) '())
   ((pair? slots)
    (append
     (agentic-ai-lab-user-loop-engine-policy-extension-slot->row
      policy-extension
      (car slots))
     (agentic-ai-lab-user-loop-engine-policy-extension-slots->rows
      policy-extension
      (cdr slots))))
   (else '())))

;;; Receipt lowering is intentionally generic: Scheme preserves POO extension
;;; inheritance, while Marlin only receives typed report-only receipt rows.
;; : (-> Value Alist)
(def (agentic-ai-lab-user-loop-engine-poo-policy-extension->receipt
      policy-extension)
  (cond
   ((agentic-ai-lab-user-loop-engine-policy-extension-kind?
     policy-extension
     +agentic-ai-lab-user-loop-engine-policy-extension-prototype-kind+)
    (let ((name (.ref policy-extension 'name))
          (receipt-kind (.ref policy-extension 'receipt-kind))
          (contract (.ref policy-extension 'contract))
          (scope (.ref policy-extension 'scope))
          (entries (.ref policy-extension 'entries)))
      (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
       'loop-engine-policy-extension 'name 'symbol (symbol? name) name)
      (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
       'loop-engine-policy-extension
       'receipt-kind
       'symbol
       (symbol? receipt-kind)
       receipt-kind)
      (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
       'loop-engine-policy-extension
       'contract
       'symbol
       (symbol? contract)
       contract)
      (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-symbol-slot
       'loop-engine-policy-extension 'scope scope)
      (agentic-ai-lab-user-loop-engine-policy-extension-require-alist-slot
       'loop-engine-policy-extension 'entries entries)
      (append
       (list (cons 'kind receipt-kind)
             (cons 'contract contract)
             (cons 'name name))
       (agentic-ai-lab-user-loop-engine-policy-extension-optional-row 'scope scope)
       (agentic-ai-lab-user-loop-engine-policy-extension-slots->rows
        policy-extension
        +agentic-ai-lab-user-loop-engine-policy-extension-slots+)
       entries
       (list (cons 'runtime-owner "marlin-agent-core")
             (cons 'runtime-executed #f)))))
   (else
    (error
     "loop-engine policy-extensions slot entries must extend loop-engine-policy-extension"
     policy-extension))))

;;; Boundary: user loop engine poo policy extensions to receipts is the policy-
;;; visible edge for module-system, loop behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> [Value] [Alist])
(def (agentic-ai-lab-user-loop-engine-poo-policy-extensions->receipts
      policy-extensions)
  (cond
   ((null? policy-extensions) '())
   ((pair? policy-extensions)
    (cons
     (agentic-ai-lab-user-loop-engine-poo-policy-extension->receipt
      (car policy-extensions))
     (agentic-ai-lab-user-loop-engine-poo-policy-extensions->receipts
      (cdr policy-extensions))))
   (else
    (error "loop-engine profile policy-extensions slot must be a list"
           policy-extensions))))
