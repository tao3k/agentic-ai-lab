;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic helpers for sandbox-core profile support projections.
;;; Invariant: generated rows are plain alists at derivation metadata,
;;; validation, policy, and presentation receipt boundaries.

(export agentic-ai-lab-sandbox-profile-rows/tail
        agentic-ai-lab-sandbox-profile-rows-into/rev
        agentic-ai-lab-sandbox-profile-field-rows
        agentic-ai-lab-sandbox-profile-field-rows/tail)

;; : (-> List List List)
;;; Sandbox profile projection helpers build bounded row lists for profile macros.
;;; - Keep row-tail helpers pure so module syntax only forwards validated policy rows.
;; : (-> List List List)
(def (agentic-ai-lab-sandbox-profile-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> List List List)
(def (agentic-ai-lab-sandbox-profile-rows-into/rev rows rows-rev)
  (if (null? rows)
    rows-rev
    (agentic-ai-lab-sandbox-profile-rows-into/rev
     (cdr rows)
     (cons (car rows) rows-rev))))

;;; Boundary: sandbox profile field rows keep generated projections hygienic
;;; while preserving policy-visible profile slot names.
;; agentic-ai-lab-sandbox-profile-field-rows
;; : (-> SandboxProfileFieldRowsClauseSyntax SandboxProfileFieldRowsExpansionSyntax)
;; | doc m%
;;   Expands sandbox profile field clauses into stable policy-visible rows.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-sandbox-profile-field-rows (filesystem 'workspace))
;;   ;; => ((filesystem . workspace))
;;   ```
(defrules agentic-ai-lab-sandbox-profile-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;;; Boundary: tail field-row expansion preserves the same projection ABI for
;;; variadic sandbox profile object clauses.
;; agentic-ai-lab-sandbox-profile-field-rows/tail
;; : (-> SandboxProfileFieldRowsTailSyntax SandboxProfileFieldRowsExpansionSyntax)
;; | doc m%
;;   Prepends sandbox profile field rows to an existing tail expression.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-sandbox-profile-field-rows/tail tail (network 'none))
;;   ;; => (agentic-ai-lab-sandbox-profile-rows/tail ((network . none)) tail)
;;   ```
(defrules agentic-ai-lab-sandbox-profile-field-rows/tail ()
  ((_ tail (field value) ...)
   (agentic-ai-lab-sandbox-profile-rows/tail
    (agentic-ai-lab-sandbox-profile-field-rows (field value) ...)
    tail)))
