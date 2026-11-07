;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: selector syntax owns the user-facing selector authoring facade for
;;; session graph and child-agent addressing.
;;; Invariant: selector expansion must keep fallback and parent-child ancestry
;;; visible to policy validation.
(import :agentic-ai-lab/modules/session/config-session-runtime)

(export session-selector-candidate
        session-selector)

;; session-selector-candidate
;;   : (-> Syntax PooSessionSelectorCandidate)
;;   | doc m%
;;       Selector candidates are declarative routing choices, not model calls.
;;     %
;; session-selector-candidate
;; : (-> SessionSelectorCandidateSyntax SessionSelectorCandidateObject)
;; | doc m%
;;   Build a candidate route for session selection, including target
;;   ownership, required receipt fields, and optional metadata.
;;   # Examples
;;   ```scheme
;;   (session-selector-candidate worker (kind agent) (target worker) (description "worker") (requires sandbox))
;;   ;; => session-selector-candidate object
;;   ```
(defrules session-selector-candidate
  (kind target description requires metadata)
  ((_ candidate-id
      (kind candidate-kind)
      (target target-ref)
      (description description-value)
      (requires required-receipt-field ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-selector-candidate
    'candidate-id
    'candidate-kind
    'target-ref
    'description-value
    '(required-receipt-field ...)
    '(metadata-entry ...)))
  ((_ candidate-id
      (kind candidate-kind)
      (target target-ref)
      (description description-value)
      (requires required-receipt-field ...))
   (agentic-ai-lab-session-syntax-selector-candidate
    'candidate-id
    'candidate-kind
    'target-ref
    'description-value
    '(required-receipt-field ...))))

;; session-selector
;;   : (-> Syntax PooSessionSelectorReceipt)
;;   | doc m%
;;       Selector declarations stay pending receipts; scoring and dispatch are
;;       runtime responsibilities.
;;     %
;; session-selector
;; : (-> SessionSelectorSyntax SessionSelectorObject)
;; | doc m%
;;   Build a session selector receipt that chooses among candidate sessions
;;   under a project root with policy and fallback metadata.
;;   # Examples
;;   ```scheme
;;   (session-selector pick (project demo) (root root) (input root) (candidates worker) (policy) (fallback root))
;;   ;; => session-selector object
;;   ```
(defrules session-selector
  (project root input candidates policy fallback metadata)
  ((_ selector-id
      (project project-id)
      (root root-session-ref)
      (input input-session-ref)
      (candidates candidate ...)
      (policy policy-entry ...)
      (fallback fallback-ref)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-selector
    'selector-id
    'project-id
    'root-session-ref
    'input-session-ref
    (list candidate ...)
    '(policy-entry ...)
    'fallback-ref
    '(metadata-entry ...)))
  ((_ selector-id
      (project project-id)
      (root root-session-ref)
      (input input-session-ref)
      (candidates candidate ...)
      (policy policy-entry ...)
      (fallback fallback-ref))
   (agentic-ai-lab-session-syntax-selector
    'selector-id
    'project-id
    'root-session-ref
    'input-session-ref
    (list candidate ...)
    '(policy-entry ...)
    'fallback-ref)))

;; : (-> PooSessionSelectorReceipt Alist)
;;; Boundary: selector syntax owns the user-facing selector authoring facade for
;;; session graph and child-agent addressing.
;;; Invariant: selector expansion must keep fallback and parent-child ancestry
;;; visible to policy validation.
