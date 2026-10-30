;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine POO object slot contract validators.
;;; Invariant: malformed declarations fail before report rows are projected.

(export agentic-ai-lab-user-loop-engine-require
        agentic-ai-lab-user-loop-engine-require-slot
        agentic-ai-lab-user-loop-engine-require-alist-slot
        agentic-ai-lab-user-loop-engine-require-symbol-list-slot
        agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
        agentic-ai-lab-user-loop-engine-require-maybe-string-slot
        agentic-ai-lab-user-loop-engine-require-maybe-integer-slot
        agentic-ai-lab-user-loop-engine-require-maybe-symbol-or-string-slot)

;; agentic-ai-lab-user-loop-engine-require
;;   : (-> LoopEngineContractMessage Boolean LoopEngineRejectedValue Unit)
;;   | contract: raises a loop-engine declaration error when the supplied
;;       predicate result is false
;;   | result: returns void when the slot check succeeds
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-user-loop-engine-require "ok" #t 'value)
;;       ;; => (void)
;;       ```
;;     %
(def (agentic-ai-lab-user-loop-engine-require message ok? value)
  (if ok? (void) (error message value)))

;;; Slot failures carry object and slot names so user-interface fixtures can
;;; point agents back to the declaration that must be fixed.
;; : (-> Symbol Symbol Symbol Boolean Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-slot object slot expected ok? value)
  (agentic-ai-lab-user-loop-engine-require
   "loop-engine POO object slot contract failed"
   ok?
   (list (cons 'object object)
         (cons 'slot slot)
         (cons 'expected expected)
         (cons 'value value))))

;;; Alist slots are the common extension channel for metadata and family-owned
;;; rows. Requiring a proper alist keeps later append-based projection total.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-alist-slot object slot value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   'alist
   (and (list? value) (andmap pair? value))
   value))

;;; Symbol-list slots model enum-like policy knobs. They are data declarations,
;;; not command selectors or runtime callbacks.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-symbol-list-slot object slot value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   '(list symbol)
   (and (list? value) (andmap symbol? value))
   value))

;;; Optional symbol slots use `#f` for no declaration and symbols for report
;;; vocabulary that Marlin can later interpret.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot object slot value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   '(maybe symbol)
   (or (not value) (symbol? value))
   value))

;;; Optional string slots carry user-facing paths or labels while keeping the
;;; Scheme side out of filesystem/runtime interpretation.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-maybe-string-slot object slot value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   '(maybe string)
   (or (not value) (string? value))
   value))

;;; Optional integer slots describe bounded counts such as attempts or budgets;
;;; runtime scheduling remains outside Scheme.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-maybe-integer-slot object slot value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   '(maybe integer)
   (or (not value) (integer? value))
   value))

;;; Goal slots may be symbolic workflow vocabulary or readable strings. Both
;;; remain declarative facts.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-require-maybe-symbol-or-string-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-require-slot
   object
   slot
   '(maybe symbol-or-string)
   (or (not value) (symbol? value) (string? value))
   value))
