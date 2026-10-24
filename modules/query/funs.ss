;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure Query admission over one immutable ElementSpace.
;;; Invariant: admission validates selection but performs no Provider execution.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        (only-in :gerbil/core hash-get hash-put!)
        (only-in :std/list/list filter)
        (only-in "types.ss"
                 agentic-ai-lab-query-admission-receipt-kind
                 AgenticAILabQueryAdmissionReceipt
                 agentic-ai-lab-query?
                 agentic-ai-lab-query-element-space?))

(export agentic-ai-lab-query-admit)

(def (query-element-index element-identities)
  (let (index (make-hash-table))
    (for-each (lambda (identity) (hash-put! index identity #t))
              element-identities)
    index))

(def (query-missing-selected-elements query element-space)
  (let (index (query-element-index (.ref element-space 'element-identities)))
    (filter (lambda (identity) (not (hash-get index identity)))
            (.ref query 'selected-element-identities))))

(def (query-admission-diagnostics query element-space)
  (let ((diagnostics '()))
    (unless (equal? (.ref query 'element-space-identity)
                    (.ref element-space 'identity))
      (set! diagnostics
            (cons (list 'element-space-identity-mismatch
                        (.ref query 'element-space-identity)
                        (.ref element-space 'identity))
                  diagnostics)))
    (unless (equal? (.ref query 'semantic-revision)
                    (.ref element-space 'semantic-revision))
      (set! diagnostics
            (cons (list 'semantic-revision-mismatch
                        (.ref query 'semantic-revision)
                        (.ref element-space 'semantic-revision))
                  diagnostics)))
    (let (missing (query-missing-selected-elements query element-space))
      (unless (null? missing)
        (set! diagnostics
              (cons (list 'undeclared-selected-elements missing)
                    diagnostics))))
    (when (and (eq? (.ref query 'completeness-requirement) 'complete)
               (not (.ref element-space 'complete?)))
      (set! diagnostics
            (cons '(incomplete-element-space) diagnostics)))
    (reverse diagnostics)))

(def (agentic-ai-lab-query-admit query element-space)
  (unless (agentic-ai-lab-query? query)
    (error "invalid canonical Query" query))
  (unless (agentic-ai-lab-query-element-space? element-space)
    (error "invalid canonical Query ElementSpace" element-space))
  ;; Keep the lexical binding distinct from the public slot name.  In native
  ;; POO object syntax an identifier matching a slot is a self reference; using
  ;; `diagnostics` here would therefore define the slot in terms of itself.
  (let (diagnostic-values (query-admission-diagnostics query element-space))
    (validate
     AgenticAILabQueryAdmissionReceipt
     (.o kind: agentic-ai-lab-query-admission-receipt-kind
         query-identity: (.ref query 'identity)
         query-version: (.ref query 'version)
         semantic-revision: (.ref query 'semantic-revision)
         element-space-identity: (.ref query 'element-space-identity)
         language-identity: (.ref (.ref query 'language) 'identity)
         accepted?: (null? diagnostic-values)
         diagnostics: diagnostic-values
         mutation-authority?: #f
         action-authority?: #f
         runtime-executed?: #f))))
