;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic helpers for workflow CI/CD final row projections.
;;; Invariant: generated rows are plain alists at POO object, runtime manifest,
;;; receipt, pipeline, and Marlin handoff boundaries.

(export yuanxu-cicd-rows/tail
        yuanxu-cicd-rows-into/rev
        yuanxu-cicd-field-rows
        yuanxu-cicd-field-rows/tail)

;; : (-> List List List)
(def (yuanxu-cicd-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> List List List)
(def (yuanxu-cicd-rows-into/rev rows rows-rev)
  (if (null? rows)
    rows-rev
    (yuanxu-cicd-rows-into/rev
     (cdr rows)
     (cons (car rows) rows-rev))))

;;; Boundary: CI/CD field rows keep workflow projection macros hygienic while
;;; preserving pipeline slot names for runtime handoff.
;; yuanxu-cicd-field-rows
;; : (-> CicdFieldRowsClauseSyntax CicdFieldRowsExpansionSyntax)
;; | doc m%
;;   Expands CI/CD pipeline field clauses into stable projection rows.
;;   # Examples
;;   ```scheme
;;   (yuanxu-cicd-field-rows (pipeline 'default))
;;   ;; => ((pipeline . default))
;;   ```
(defrules yuanxu-cicd-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;;; Boundary: CI/CD tail field rows preserve the projection ABI for variadic
;;; pipeline clauses.
;; yuanxu-cicd-field-rows/tail
;; : (-> CicdFieldRowsTailSyntax CicdRowsExpansionSyntax)
;; | doc m%
;;   Prepends CI/CD field rows to an existing pipeline row tail.
;;   # Examples
;;   ```scheme
;;   (yuanxu-cicd-field-rows/tail tail (checks 'unit))
;;   ;; => (yuanxu-cicd-rows/tail ((checks . unit)) tail)
;;   ```
(defrules yuanxu-cicd-field-rows/tail ()
  ((_ tail (field value) ...)
   (yuanxu-cicd-rows/tail
    (yuanxu-cicd-field-rows (field value) ...)
    tail)))
