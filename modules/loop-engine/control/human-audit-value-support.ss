;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure value-shape predicates shared by human-audit validation.

(export #t)

;;; Boundary: loop human audit alist ref is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Alist Symbol Value Value)
(def (loop-human-audit-alist-ref alist key default)
  (cond
   ((assoc key alist) => cdr)
   (else default)))

;; | LoopHumanAuditDecisionCandidate = Symbol
;; : (-> LoopHumanAuditDecisionCandidate (List LoopHumanAuditDecisionCandidate) Boolean)
(def (loop-human-audit-member? value values)
  (cond
   ((null? values) #f)
   ((equal? value (car values)) #t)
   (else
    (loop-human-audit-member? value (cdr values)))))

;; loop-human-audit-alist?
;;   : (-> PooFlowValue Boolean)
;;   | doc m%
;;       Recognize proper alist values used by audit review projections.
;;       # Examples
;;       (loop-human-audit-alist? '((mode . review-loop)))
;;       # Result
;;       #t for proper association lists.
;;     %
(def (loop-human-audit-alist? value)
  (and (list? value) (andmap pair? value)))

;; loop-human-audit-list-of?
;;   : (-> (-> PooFlowValue Boolean) PooFlowValue Boolean)
;;   | doc m%
;;       Recognize proper human-audit lists whose elements satisfy a predicate.
;;       # Examples
;;       (loop-human-audit-list-of? symbol? '(pending approved))
;;       # Result
;;       #t when every element satisfies the supplied predicate.
;;     %
(def (loop-human-audit-list-of? predicate values)
  (and (list? values) (andmap predicate values)))

;; : (-> PooFlowValue Boolean)
(def (loop-human-audit-state-fact-list? value)
  (loop-human-audit-list-of? loop-human-audit-alist? value))

;; : (-> PooFlowValue Boolean)
(def (loop-human-audit-governor-contract? value)
  (or (not value)
      (loop-human-audit-alist? value)))
