;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: normalizes governor policy descriptors into membership sets.
;;; Invariant: set construction preserves descriptor action identities and equality semantics.
(import :gerbil/core
        :poo-flow/modules/loop-engine/control/descriptor
        :poo-flow/modules/loop-engine/control/governor-core)

(export loop-governor-pattern-action-key
        loop-governor-member?
        loop-governor-value-set
        loop-governor-set-member?
        loop-governor-pattern-denied-by-set?
        loop-governor-pattern-conflicted-by-set?
        loop-governor-pattern-open?)

;; Boundary: set-backed governor checks are pure policy projections over
;; descriptor metadata; governor-policy.ss owns the higher-level flow.
(def (loop-governor-pattern-action-key descriptor)
  (loop-governor-alist-ref (loop-pattern-metadata descriptor)
                           'acting_on
                           (loop-pattern-name descriptor)))

(def (loop-governor-member? value values)
  (cond
   ((null? values) #f)
   ((equal? value (car values)) #t)
   (else
    (loop-governor-member? value (cdr values)))))

(def (loop-governor-value-set values)
  (let (table (make-hash-table))
    (for-each
     (lambda (value)
       (hash-put! table value #t))
     values)
    table))

(def (loop-governor-set-member? table value)
  (and value (hash-get table value)))

(def (loop-governor-pattern-denied-by-set? descriptor denylist-set)
  (let ((action-key (loop-governor-pattern-action-key descriptor))
        (pattern-name (loop-pattern-name descriptor)))
    (or (loop-governor-set-member? denylist-set action-key)
        (loop-governor-set-member? denylist-set pattern-name))))

(def (loop-governor-pattern-conflicted-by-set? descriptor state-action-key-set)
  (let (action-key (loop-governor-pattern-action-key descriptor))
    (and action-key
         (loop-governor-set-member? state-action-key-set action-key))))

(def (loop-governor-pattern-open? denied? conflicted?)
  (and (not denied?) (not conflicted?)))
